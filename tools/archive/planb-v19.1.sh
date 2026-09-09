#!/usr/bin/env bash
# planb-v19.1.sh — LED DTB: dual rg @ gpio0_B0 (heartbeat) + yellow @ gpio1_B1.
# Kernel = v19 zImage (already built, has LEDS_TRIGGER_HEARTBEAT).
# Flash BOTH: boot.img -> 0xE000, resource.img -> 0x6800.
set -euo pipefail

W=/workspace/work
OUT=/workspace/output/planb-stock-uboot
SRC=/vol/kernel-src
B=/vol/kernel-build
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+

echo "=== 1. patch dts with LED nodes ==="
python3 /workspace/tools/v19.1-dts.py "$W/xmio-planb-v17.dts" "$W/xmio-planb-v19.1.dts"

echo "=== 2. compile dtb + verify ==="
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v19.1.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null > /tmp/v191-check.dts
python3 - <<'EOF'
d = open('/tmp/v191-check.dts').read()
assert 'local-mac-address = [02 31 28 16 01 28];' in d, 'MAC lost!'
i = d.index('\tmmc@10214000 {')
blk = d[i:i+900]
assert 'status = "okay";' in blk and 'broken-cd' in blk, 'sdmmc not enabled!'
a = d.index('\ttimer@20044000 {'); b2 = d.index('\ttimer@20044020 {')
assert a < b2, 'timer order wrong!'
assert 'gpio-leds' in d, 'leds node missing!'
assert 'xmio:red-green:status' in d, 'status led missing!'
assert 'xmio:yellow:io' in d, 'yellow led missing!'
assert 'heartbeat' in d, 'heartbeat trigger missing!'
# gpios cells: dtc prints cells in hex (0x8), accept both forms
import re
leds = d[d.index('xmio-leds'):d.index('xmio-leds')+1200]
assert re.search(r'gpios = <0x[0-9a-f]+ (?:0x0?8|8) 0x00>', leds), 'dual pin cell wrong'
assert re.search(r'gpios = <0x[0-9a-f]+ (?:0x0?9|9) 0x00>', leds), 'yellow pin cell wrong'
# the two phandles must differ
phs = re.findall(r'gpios = <(0x[0-9a-f]+) ', leds)
assert len(phs) == 2 and phs[0] != phs[1], 'phandles identical'
# ph0 -> gpio0 node, ph1 -> gpio1 node
h0 = d.index('gpio@2007c000 {'); h0b = d[h0:h0+400]
assert phs[0] in h0b, 'dual led not on gpio0!'
h1 = d.index('gpio@20080000 {'); h1b = d[h1:h1+400]
assert phs[1] in h1b, 'yellow led not on gpio1!'
print('DTB verify OK (LEDs + MAC + sdmmc + timer2)')
EOF

echo "=== 3. repack resource.img + boot.img (v19 kernel) ==="
python3 /workspace/tools/pack_resource.py "$OUT/resource.img" \
  "path=$OUT/rk3128-xmio-planb.dtb,name=rk-kernel.dtb"
mkbootimg --kernel /workspace/output/kernel/zImage \
  --ramdisk "$OUT/initrd.img.gz" \
  --second "$OUT/resource.img" \
  --base 0x60000000 --kernel_offset 0x00408000 \
  --ramdisk_offset 0x02000000 --second_offset 0x00F00000 \
  --tags_offset 0x00088000 --pagesize 16384 \
  --cmdline "" --output "$OUT/boot.img"
python3 - <<'EOF'
import struct
d = open('/workspace/output/planb-stock-uboot/boot.img','rb').read()
f = struct.unpack_from('<8s10I', d, 0)
k0,k1,r0,r1,s0,s1 = f[2],f[2]+f[1],f[4],f[4]+f[3],f[6],f[6]+f[5]
def ov(a0,a1,b0,b1): return max(a0,b0)<min(a1,b1)
assert not ov(k0,k1,s0,s1) and not ov(k0,k1,r0,r1) and not ov(r0,r1,s0,s1)
print('RAM LAYOUT OK')
EOF

echo "=== 4. hashes + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.v14diag.bak parameter.txt.v16.bak \
  parameter.txt.badnand1 parameter.txt.native uboot-stock.img misc.img \
  baseparamer-720P.img resource.img resource-baseline.img boot.img \
  rk3128-xmio-planb.dtb "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
md5sum "$OUT/boot.img" "$OUT/resource.img" "$OUT/rk3128-xmio-planb.dtb"
echo PLANB_V19_1_DONE
