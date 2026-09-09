#!/usr/bin/env bash
# planb-v23-testimg.sh — build lại boot v23 nguyên bản (kernel KHÔNG có
# patch vendor-node + DTB v23 không local-mac-address) thành file RIÊNG
# boot-v23.img để test tính bền của vendor storage, không đè boot.img v24.
set -euo pipefail

OUT=/workspace/output/planb-stock-uboot
SRC=/vol/kernel-src
B=/vol/kernel-build
W=/workspace/work
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. revert v24 kernel patch (ve trang thai v23) ==="
if [ -f "$SRC/drivers/rk_nand/rk_nand_blk.c.orig-v23" ]; then
  cp -f "$SRC/drivers/rk_nand/rk_nand_blk.c.orig-v23" "$SRC/drivers/rk_nand/rk_nand_blk.c"
  grep -c 'exposing vendor_storage' "$SRC/drivers/rk_nand/rk_nand_blk.c" || echo "patch reverted OK"
else
  echo "no backup found - source already at v23 state?"
fi

echo "=== 2. build zImage v23 ==="
cd "$SRC"
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make -j"$(nproc)" O="$B" zImage > /workspace/work/v23t-build.log 2>&1 || {
  tail -30 /workspace/work/v23t-build.log; exit 1; }
tail -2 /workspace/work/v23t-build.log

echo "=== 3. DTB v23 (khong MAC) ==="
dtc -I dts -O dtb -o /tmp/v23-test.dtb "$W/xmio-planb-v23.dts" 2>/dev/null
dtc -I dtb -O dts /tmp/v23-test.dtb 2>/dev/null > /tmp/v23t-check.dts
python3 - <<'EOF'
import re
d = open('/tmp/v23t-check.dts').read()
i = d.index('\tethernet@2008c000 {'); blk = d[i:i+1400]
assert 'local-mac-address' not in blk, 'DTB has MAC - wrong source!'
assert 'status = "okay"' in blk
print('DTB v23 OK: ethernet node has NO local-mac-address')
EOF

echo "=== 4. pack resource test + boot-v23.img (file rieng) ==="
python3 /workspace/tools/pack_resource.py /tmp/v23-test-resource.img \
  "path=/tmp/v23-test.dtb,name=rk-kernel.dtb"
mkbootimg --kernel "$B/arch/arm/boot/zImage" \
  --ramdisk "$OUT/initrd.img.gz" \
  --second /tmp/v23-test-resource.img \
  --base 0x60000000 --kernel_offset 0x00408000 \
  --ramdisk_offset 0x02000000 --second_offset 0x00F00000 \
  --tags_offset 0x00088000 --pagesize 16384 \
  --cmdline "" --output "$OUT/boot-v23.img"
python3 - <<'EOF'
import struct
d = open('/workspace/output/planb-stock-uboot/boot-v23.img','rb').read()
f = struct.unpack_from('<8s10I', d, 0)
k0,k1,r0,r1,s0,s1 = f[2],f[2]+f[1],f[4],f[4]+f[3],f[6],f[6]+f[5]
def ov(a0,a1,b0,b1): return max(a0,b0)<min(a1,b1)
assert not ov(k0,k1,s0,s1) and not ov(k0,k1,r0,r1) and not ov(r0,r1,s0,s1)
print('RAM LAYOUT OK')
EOF

echo "=== 5. restore trang thai v24 (re-apply patch + rebuild) ==="
python3 /workspace/tools/v24-kpatch.py
make -j"$(nproc)" O="$B" zImage >> /workspace/work/v23t-build.log 2>&1
strings "$B/vmlinux" | grep -q 'exposing vendor_storage' && echo "kernel build dir back to v24"

echo "=== 6. hashes ==="
md5sum "$OUT/boot-v23.img" "$OUT/boot.img"
sha256sum "$OUT/boot-v23.img"
echo PLANB_V23_TESTIMG_DONE
