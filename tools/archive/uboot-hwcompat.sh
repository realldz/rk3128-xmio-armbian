#!/bin/bash
# uboot-hwcompat.sh — điều tra tương thích phần cứng uboot-v1 vs factory uboot vs XMIO
set -uo pipefail
DTC=dtc

echo "############ 1. DEBUG_UART init trong code uboot-v1 ############"
grep -rn "board_debug_uart_init" /vol/uboot-src/board/ /vol/uboot-src/arch/arm/mach-rockchip/ 2>/dev/null | grep -v Binary | head -5
F=$(grep -rln "board_debug_uart_init" /vol/uboot-src/board/rockchip/ 2>/dev/null | head -1)
echo "--- file: $F"
grep -n -B3 -A25 "board_debug_uart_init" "$F" 2>/dev/null | head -45

echo
echo "############ 2. DTB nhúng trong uboot-v1: chosen/serial/uart ############"
$DTC -I dtb -O dts /vol/uboot-build/u-boot.dtb > /tmp/ubv1.dts 2>/dev/null || echo DTC_FAIL
grep -n -A6 "chosen" /tmp/ubv1.dts | head -14
grep -n "stdout-path\|serial@2006" /tmp/ubv1.dts | head -12

echo
echo "############ 3. UART nodes trong DTB uboot-v1 (status + pinctrl) ############"
awk '/serial@2006/,/};/' /tmp/ubv1.dts | grep -E "serial@2006|compatible|status|pinctrl-0|clock-frequency" | head -20

echo
echo "############ 4. ADC keys trong DTB uboot-v1 ############"
awk '/adc/,0' /tmp/ubv1.dts | head -40

echo
echo "############ 5. Trích DTB từ factory uboot-stock payload ############"
python3 - <<'EOF'
data = open('/tmp/stock-unpack.bin','rb').read()
magic = bytes([0xd0,0x0d,0xfe,0xed])
idx = data.find(magic)
print("dtb magic at offset:", idx)
if idx >= 0:
    # totalsize = big-endian u32 at idx+4
    import struct
    size = struct.unpack('>I', data[idx+4:idx+8])[0]
    print("dtb totalsize:", size)
    open('/tmp/stockub.dtb','wb').write(data[idx:idx+size])
EOF
if [ -f /tmp/stockub.dtb ]; then
  $DTC -I dtb -O dts /tmp/stockub.dtb > /tmp/stockub.dts 2>/dev/null || echo DTC_FAIL_STOCK
  echo "--- chosen/stdout:"
  grep -n -A5 "chosen" /tmp/stockub.dts | head -12
  echo "--- serial nodes status:"
  awk '/serial@2006/,/};/' /tmp/stockub.dts | grep -E "serial@2006|compatible|status" | head -12
  echo "--- adc/key nodes:"
  grep -n "adc\|key" /tmp/stockub.dts | head -15
fi
