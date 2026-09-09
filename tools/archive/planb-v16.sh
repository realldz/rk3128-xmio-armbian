#!/usr/bin/env bash
# planb-v16.sh — SD card enable + FTL background GC restore + codec spam off.
#  kernel: v16-gc-restore.py (undo v12 GC-off workaround) -> rebuild zImage
#  dtb:    v16-dts.py (v9 -> v16.dts: sdmmc okay+broken-cd, codecs off)
#  pack:   resource.img + boot.img repack, hashes, bundle
# Flash: boot.img -> 0xE000, resource.img -> 0x6800. rootfs giữ nguyên.
set -euo pipefail

W=/workspace/work
OUT=/workspace/output/planb-stock-uboot
SRC=/vol/kernel-src
B=/vol/kernel-build
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. restore vendor background GC in kernel ==="
python3 /workspace/tools/v16-gc-restore.py

echo "=== 2. rebuild zImage ==="
cd "$SRC"
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make -j"$(nproc)" O="$B" zImage > /workspace/work/v16-build.log 2>&1 || {
  tail -40 /workspace/work/v16-build.log; exit 1; }
tail -3 /workspace/work/v16-build.log

echo "=== 2b. verify GC re-arm present ==="
if strings "$B/vmlinux" | grep -q "FtlWrite: lpa error"; then
  echo "blob strings OK"
fi
grep -n "rk_ftl_gc_do = 1;" "$SRC/drivers/rk_nand/rk_nand_blk.c"
grep -c "rk_ftl_gc_do = 0" "$SRC/drivers/rk_nand/rk_nand_blk.c" || true

echo "=== 3. build v16 DTB ==="
python3 /workspace/tools/v16-dts.py "$W/xmio-planb-v9.dts" "$W/xmio-planb-v16.dts"
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v16.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null > /tmp/v16-check.dts
python3 - <<'EOF'
d = open('/tmp/v16-check.dts').read()
assert 'local-mac-address = [02 31 28 16 01 28];' in d, 'MAC lost!'
i = d.index('\tmmc@10214000 {')
blk = d[i:i+900]
assert 'status = "okay";' in blk and 'broken-cd' in blk, 'sdmmc not enabled!'
j = d.index('\thevc@10104000 {')
blk = d[j:j+700]
assert 'status = "disabled";' in blk, 'codec not disabled!'
print('DTB verify: MAC kept, sdmmc enabled+broken-cd, codecs disabled')
EOF

echo "=== 4. repack resource.img + boot.img ==="
python3 /workspace/tools/pack_resource.py "$OUT/resource.img" \
  "path=$OUT/rk3128-xmio-planb.dtb,name=rk-kernel.dtb"
cp -f "$B/arch/arm/boot/zImage" /workspace/output/kernel/zImage
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

echo "=== 5. hashes + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.v14diag.bak uboot-stock.img misc.img \
  baseparamer-720P.img resource.img resource-baseline.img boot.img \
  rk3128-xmio-planb.dtb "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
echo PLANB_V16_DONE
