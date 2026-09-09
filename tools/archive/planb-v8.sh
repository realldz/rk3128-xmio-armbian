#!/usr/bin/env bash
# Plan B v8: disable uart1/uart2 (hang source) + clean cmdline to UART0-only console
exec > /workspace/work/planb-v8.log 2>&1
set -e
W=/workspace/work
OUT=/workspace/output/planb-stock-uboot

echo "=== 1. v8 DTS: disable serial@20064000 and serial@20068000 ==="
python3 - "$W/xmio-planb-v6.dts" "$W/xmio-planb-v8.dts" <<'EOF'
import sys, re
t = open(sys.argv[1], encoding='utf-8').read()
for addr in ('20064000', '20068000'):
    m = re.search(r'(\tserial@%s \{(?:[^{]|\{[^{}]*\})*?\t\};\n)' % addr, t)
    assert m, f'serial@{addr} not found'
    blk = m.group(1)
    assert 'status = "okay";' in blk
    t = t.replace(blk, blk.replace('status = "okay";', 'status = "disabled";'), 1)
open(sys.argv[2], 'w', encoding='utf-8').write(t)
print('v8 DTS written')
EOF

echo "=== 2. compile + sanity ==="
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v8.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" > /tmp/v8-check.dts 2>/dev/null
python3 - <<'EOF'
import re
d = open('/tmp/v8-check.dts', encoding='utf-8').read()
def blk(addr):
    m = re.search(r'serial@%s \{([^}]*)\}' % addr, d)
    assert m, f'serial@{addr} missing'
    return m.group(1)
assert 'status = "okay"' in blk('20060000'), 'uart0 must stay okay'
assert 'status = "disabled"' in blk('20064000'), 'uart1 must be disabled'
assert 'status = "disabled"' in blk('20068000'), 'uart2 must be disabled'
assert '\tpsci {' not in d
assert 'smp-sram@0' in d
for srst in ('0x04', '0x05', '0x06', '0x07'):
    assert f'resets = <0x06 {srst}>;' in d, f'cpu reset {srst} missing'
print('V8 SANITY OK: uart0 only, no psci, smp-sram@0, 4 cpu resets')
EOF

echo "=== 3. rebuild resource.img + boot.img ==="
python3 /workspace/tools/pack_resource.py "$OUT/resource.img" \
  "path=$OUT/rk3128-xmio-planb.dtb,name=rk-kernel.dtb"
mkbootimg --kernel /workspace/output/kernel/zImage \
  --ramdisk "$OUT/initrd.img.gz" \
  --second "$OUT/resource.img" \
  --base 0x60000000 --kernel_offset 0x00408000 \
  --ramdisk_offset 0x02000000 --second_offset 0x00F00000 \
  --tags_offset 0x00088000 --pagesize 16384 \
  --cmdline "" --output "$OUT/boot.img"

echo "=== 4. parameter v8: UART0-only console ==="
python3 - "$OUT/parameter.txt" <<'EOF'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
for cut in (' earlycon=uart8250,mmio32,0x20068000',
            ' console=ttyS1,115200',
            ' console=ttyS2,115200'):
    assert cut in t, f'missing {cut!r}'
    t = t.replace(cut, '')
assert 'earlycon=uart8250,mmio32,0x20060000 console=tty1 console=ttyS0,115200' in t
open(p, 'w', encoding='utf-8').write(t)
print('parameter v8 written')
EOF
grep CMDLINE "$OUT/parameter.txt" | head -c 300; echo

echo "=== 5. layout + hashes ==="
python3 - <<'EOF'
import struct
d = open('/workspace/output/planb-stock-uboot/boot.img','rb').read()
f = struct.unpack_from('<8s10I', d, 0)
k0,k1,r0,r1,s0,s1 = f[2],f[2]+f[1],f[4],f[4]+f[3],f[6],f[6]+f[5]
def ov(a0,a1,b0,b1): return max(a0,b0)<min(a1,b1)
assert not ov(k0,k1,s0,s1) and not ov(k0,k1,r0,r1) and not ov(r0,r1,s0,s1)
print('kernel %d | ramdisk %d | second %d @ %#x | RAM LAYOUT OK' % (f[1],f[3],f[5],f[6]))
EOF
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt uboot-stock.img misc.img baseparamer-720P.img \
  resource.img resource-baseline.img boot.img rk3128-xmio-planb.dtb \
  "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
echo PLANB_V8_DONE
