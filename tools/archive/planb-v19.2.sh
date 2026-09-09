#!/usr/bin/env bash
# planb-v19.2.sh — yellow LED GPIO_ACTIVE_LOW + (no kernel change).
# Kernel zImage = v19 (unchanged). Flash BOTH boot.img and resource.img.
set -euo pipefail

W=/workspace/work
OUT=/workspace/output/planb-stock-uboot
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+

echo "=== 1. flip yellow polarity in dts ==="
python3 /workspace/tools/v19.2-dts.py "$W/xmio-planb-v19.1.dts" "$W/xmio-planb-v19.2.dts"

echo "=== 2. compile dtb + verify ==="
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v19.2.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null > /tmp/v192-check.dts
python3 - <<'EOF'
d = open('/tmp/v192-check.dts').read()
assert 'local-mac-address = [02 31 28 16 01 28];' in d, 'MAC lost!'
i = d.index('\tmmc@10214000 {'); blk = d[i:i+900]
assert 'status = "okay";' in blk and 'broken-cd' in blk, 'sdmmc not enabled!'
a = d.index('\ttimer@20044000 {'); b2 = d.index('\ttimer@20044020 {')
assert a < b2, 'timer order wrong!'
leds = d[d.index('xmio-leds'):d.index('xmio-leds')+1200]
import re
# dual still active-high (0x00), yellow now active-low (0x01)
assert re.search(r'gpios = <0x[0-9a-f]+ 0x08 0x00>', leds), 'dual flag changed!'
assert re.search(r'gpios = <0x[0-9a-f]+ 0x09 0x01>', leds), 'yellow not active-low!'
print('DTB verify OK (yellow ACTIVE_LOW, dual unchanged)')
EOF

echo "=== 3. repack (zImage unchanged from v19) ==="
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
md5sum "$OUT/boot.img" "$OUT/resource.img"
echo PLANB_V19_2_DONE
