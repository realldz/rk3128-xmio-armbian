#!/bin/bash
# v28-build.sh — kernel #28: fbdev shadow buffer + damage blit (chong tear)
set -e
B=/vol/kernel-build
OUT=/workspace/output/planb-stock-uboot

echo "=== 1. build zImage ==="
cd /vol/kernel-src
export CROSS_COMPILE=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-
export ARCH=arm LOCALVERSION=+
make O=$B olddefconfig > /workspace/work/v28-olddefconfig.log 2>&1
make -j$(nproc) O=$B zImage > /workspace/work/v28-build.log 2>&1
grep -E 'error|Error' /workspace/work/v28-build.log | head -5 || true
tail -3 /workspace/work/v28-build.log

echo "=== 2. xac nhan fbdev.o build lai sau patch ==="
ls -la --time-style=full-iso $B/drivers/gpu/drm/rockchip/rockchip_drm_fbdev.o | awk '{print $6, $7}'
date '+NOW: %F %T'

echo "=== 3. repack boot.img ==="
mkbootimg --kernel "$B/arch/arm/boot/zImage" \
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

echo "=== 4. hash ==="
md5sum "$OUT/boot.img"
sha256sum "$OUT/boot.img"
cp "$OUT/boot.img" /workspace/output/archive/boot-v28.img
echo ARCHIVED boot-v28.img
