#!/usr/bin/env bash
# Plan B v6: fix SMP holding-pen offset (mailbox must be at IMEM base 0x10080004)
#           + initcall_debug to name the hang after Bluetooth core init.
exec > /workspace/work/planb-v6.log 2>&1
set -e
W=/workspace/work
OUT=/workspace/output/planb-stock-uboot

echo "=== 1. v6 DTS: smp-sram@400 -> @0 (upstream convention) ==="
python3 - "$W/xmio-planb-v4.dts" "$W/xmio-planb-v6.dts" <<'EOF'
import sys
t = open(sys.argv[1], encoding='utf-8').read()
old = '''\t\tsmp-sram@400 {
\t\t\tcompatible = "rockchip,rk3066-smp-sram";
\t\t\treg = <0x400 0x1c00>;
\t\t};'''
new = '''\t\tsmp-sram@0 {
\t\t\tcompatible = "rockchip,rk3066-smp-sram";
\t\t\treg = <0x00 0x10>;
\t\t};'''
assert old in t, 'smp-sram@400 block not found'
t = t.replace(old, new)
assert 'smp-sram@0' in t
open(sys.argv[2], 'w', encoding='utf-8').write(t)
print('v6 DTS written')
EOF

echo "=== 2. compile + sanity ==="
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v6.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" > /tmp/v6-check.dts 2>/dev/null
python3 - <<'EOF'
d = open('/tmp/v6-check.dts', encoding='utf-8').read()
assert '\tpsci {' not in d, 'psci back!'
assert 'enable-method = "rockchip,rk3036-smp"' in d
assert 'smp-sram@0' in d, 'smp-sram@0 missing'
assert 'smp-sram@400' not in d, 'old @400 still present'
assert 'reg = <0x0 0x10>' in d or 'reg = <0x00 0x10>' in d, 'smp-sram reg wrong'
for srst in ('0x04', '0x05', '0x06', '0x07'):
    assert f'resets = <0x06 {srst}>;' in d, f'cpu reset {srst} missing'
assert 'memory@60000000' in d
print('V6 SANITY OK: smp-sram@0 (mailbox 0x10080004), no psci, 4 cpu resets')
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

echo "=== 4. parameter: add initcall_debug ==="
python3 - "$OUT/parameter.txt" <<'EOF'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
assert 'initcall_debug' not in t
t = t.replace('keep_bootcon ignore_loglevel',
              'keep_bootcon initcall_debug ignore_loglevel')
assert 'initcall_debug' in t
open(p, 'w', encoding='utf-8').write(t)
print('parameter v6 written')
EOF
grep -c initcall_debug "$OUT/parameter.txt"

echo "=== 5. verify boot.img layout + hashes ==="
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
echo PLANB_V6_DONE
