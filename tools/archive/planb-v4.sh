#!/usr/bin/env bash
# Plan B v4: fix PSCI panic (no ATF on stock chain) + enable 4-core SMP
#  - remove /psci node (SMC -> Monitor mode with no ATF = prefetch abort)
#  - /cpus enable-method = "rockchip,rk3036-smp" (bootrom mailbox, no ATF)
#  - per-cpu resets = <cru SRST_CORE0..3>  (rk3128-cru.h: ids 4..7)
#  - sram@10080000 with smp-sram@400 (holding pen at 0x10080400, matches
#    stock 3.10 "rockchip,sram" = sram@10080400; bootrom keeps first 1KB)
exec > /workspace/work/planb-v4.log 2>&1
set -e
W=/workspace/work
OUT=/workspace/output/planb-stock-uboot

echo "=== 1. v4 DTS edits ==="
python3 - "$W/xmio-planb.dts" "$W/xmio-planb-v4.dts" <<'EOF'
import sys, re
t = open(sys.argv[1], encoding='utf-8').read()

# (a) remove /psci node
m = re.search(r'\tpsci \{\n(?:[^{}]|\{[^{}]*\})*?\t\};\n\n', t)
assert m, 'psci node not found'
t = t.replace(m.group(0), '')
assert '\tpsci {' not in t

# (b) /cpus enable-method (container level, rk3036 style)
t = t.replace('\t\t#address-cells = <0x01>;\n\t\t#size-cells = <0x00>;\n\n\t\tcpu@f00 {',
              '\t\t#address-cells = <0x01>;\n\t\t#size-cells = <0x00>;\n\t\tenable-method = "rockchip,rk3036-smp";\n\n\t\tcpu@f00 {')
assert 'enable-method = "rockchip,rk3036-smp"' in t, 'cpus container not patched'

# (c) per-cpu resets (cru phandle 0x06; SRST_CORE0..3 = 4..7 per rk3128-cru.h)
for cpu, srst in (('f00', 4), ('f01', 5), ('f02', 6), ('f03', 7)):
    pat = f'reg = <0x{cpu}>;'
    assert pat in t, f'{cpu} reg not found'
    t = t.replace(pat, pat + f'\n\t\t\tresets = <0x06 {srst}>;', 1)

# (d) sram node (before memory@60000000, top level)
assert 'sram@10080000' not in t
sram = ('''\tsram@10080000 {
\t\tcompatible = "mmio-sram";
\t\treg = <0x10080000 0x2000>;
\t\t#address-cells = <1>;
\t\t#size-cells = <1>;
\t\tranges = <0 0x10080000 0x2000>;

\t\tsmp-sram@400 {
\t\t\tcompatible = "rockchip,rk3066-smp-sram";
\t\t\treg = <0x400 0x1c00>;
\t\t};
\t};

''')
idx = t.index('\tmemory@60000000 {')
t = t[:idx] + sram + t[idx:]

open(sys.argv[2], 'w', encoding='utf-8').write(t)
print('v4 DTS written')
EOF

echo "=== 2. compile + sanity ==="
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v4.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" > /tmp/v4-check.dts 2>/dev/null
python3 - <<'EOF'
import re
d = open('/tmp/v4-check.dts', encoding='utf-8').read()
assert '\tpsci {' not in d, 'psci still present!'
assert 'enable-method = "rockchip,rk3036-smp"' in d
for srst in ('0x04', '0x05', '0x06', '0x07'):
    assert f'resets = <0x06 {srst}>;' in d, f'cpu reset {srst} missing'
assert 'smp-sram@400' in d and 'rockchip,rk3066-smp-sram' in d
assert 'reg = <0x400 0x1c00>' in d or 'reg = <0x0400 0x1c00>' in d, 'smp-sram reg'
assert 'memory@60000000' in d
print('V4 SANITY OK: no psci, smp enabled, sram holding pen @0x10080400')
EOF

echo "=== 3. resource.img + boot.img ==="
python3 /workspace/tools/pack_resource.py "$OUT/resource.img" \
  "path=$OUT/rk3128-xmio-planb.dtb,name=rk-kernel.dtb"
mkbootimg --kernel /workspace/output/kernel/zImage \
  --ramdisk "$OUT/initrd.img.gz" \
  --second "$OUT/resource.img" \
  --base 0x60000000 --kernel_offset 0x00408000 \
  --ramdisk_offset 0x02000000 --second_offset 0x00F00000 \
  --tags_offset 0x00088000 --pagesize 16384 \
  --cmdline "" --output "$OUT/boot.img"

echo "=== 4. verify + hashes ==="
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
echo PLANB_V4_DONE
