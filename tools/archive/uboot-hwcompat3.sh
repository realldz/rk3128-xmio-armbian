#!/bin/bash
# uboot-hwcompat3.sh — so sánh DTB nhúng A26 vs uboot-v1; pinmux uart; key nodes; debug uart symbol
set -uo pipefail
echo "############ 1. Extract embedded DTB tu payload A26 ############"
python3 - <<'EOF'
import struct
data = open('/vol/uboot-build/unpack-a26/uboot-a26.bin','rb').read()
magic = bytes([0xd0,0x0d,0xfe,0xed])
pos, found = 0, []
while True:
    i = data.find(magic, pos)
    if i < 0: break
    found.append(i); pos = i + 4
print("candidates:", found)
for i in found:
    size = struct.unpack('>I', data[i+4:i+8])[0]
    if 1024 < size < 200000 and i + size <= len(data):
        off_mem = struct.unpack('>I', data[i+8:i+12])[0]
        if off_mem < size:
            open('/tmp/a26ub.dtb','wb').write(data[i:i+size])
            print("extracted at", i, "size", size)
            break
EOF
ls -l /tmp/a26ub.dtb 2>/dev/null && dtc -I dtb -O dts /tmp/a26ub.dtb > /tmp/a26ub.dts 2>/dev/null && echo "A26 DTB decompile OK"

echo
echo "############ 2. Diff DTB A26 vs uboot-v1 (cac node quan trong) ############"
if [ -f /tmp/a26ub.dts ]; then
  echo "--- A26 chosen/stdout:"; grep -n -A4 "chosen" /tmp/a26ub.dts | head -8
  echo "--- A26 uart1 node:"; awk '/serial1@20064000/,/};/' /tmp/a26ub.dts | head -12
  echo "--- so sanh thuan tuy:"; diff <(grep -v "^@" /tmp/a26ub.dts) <(grep -v "^@" /vol/uboot-build/u-boot.dts >/dev/null 2>&1; cat /tmp/ubv1.dts | grep -v "^@") >/dev/null 2>&1 && echo "IDENTICAL" || diff /tmp/a26ub.dts /tmp/ubv1.dts | head -40 || true
fi

echo
echo "############ 3. Pinmux uart1-xfer resolved (uboot-v1) ############"
grep -n -B4 -A8 "0x10000009" /tmp/ubv1.dts | grep -E "phandle|pins|uart1|reg =|rockchip,pins" | head -10
echo "--- uart1-xfer trong ubv1:"
grep -n -A8 "uart1-xfer\|uart1_xfer" /tmp/ubv1.dts | head -20

echo
echo "############ 4. Pinmux uart1 trong XMIO kernel DTS (tham chieu) ############"
grep -n -A6 "uart1-xfer" /workspace/work/xmio-planb-v23.dts | head -16

echo
echo "############ 5. Key nodes trong uboot-v1 DTB ############"
grep -n -B3 -A12 "adc-dm-key\|dm-key\|gpio-key\|adc_key\|rk_key" /tmp/ubv1.dts | head -40

echo
echo "############ 6. board_debug_uart_init symbol ############"
nm /vol/uboot-build/u-boot 2>/dev/null | grep -i "debug_uart" | head -8
grep -rn "board_debug_uart_init" /vol/uboot-src/board/rockchip/ /vol/uboot-src/arch/arm/mach-rockchip/ /vol/uboot-src/drivers/serial/ 2>/dev/null | grep -v Binary | head -6
