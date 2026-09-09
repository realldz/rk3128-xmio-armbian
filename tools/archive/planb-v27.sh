#!/bin/bash
# v27-build.sh — kernel #27: inno_hdmi mode_valid cap 165MHz
set -e
B=/vol/kernel-build
OUT=/workspace/output/planb-stock-uboot

echo "=== 1. build kernel (giu nguon, chi build lai) ==="
cd /vol/kernel-src
export CROSS_COMPILE=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-
export ARCH=arm LOCALVERSION=+
make O=$B olddefconfig > /workspace/work/v27-olddefconfig.log 2>&1
make -j$(nproc) O=$B zImage > /workspace/work/v27-build.log 2>&1
tail -3 /workspace/work/v27-build.log
REL=$(make O=$B kernelrelease 2>/dev/null)
echo "kernelrelease=$REL"

echo "=== 2. kiem tra patch co mat trong Object (const 165000 = 0x28488) ==="
TC=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-
$TC-objdump -d $B/drivers/gpu/drm/rockchip/inno_hdmi.o | awk '/<inno_hdmi_connector_mode_valid>:/,/^$/' | head -20
od -A x -t x1 $B/drivers/gpu/drm/rockchip/inno_hdmi.o | grep -m1 '88 84 02 00' \
  && echo "CAP 165MHz PRESENT" || { echo "cap MISSING!"; exit 1; }

echo "=== 3. resource: giu nguyen DTB v23.2 hien hanh ==="
# resource.img hien tai da chua DTB b218d71d — khong dong, dung lai

echo "=== 4. repack boot.img (zImage moi + initrd + resource hien hanh) ==="
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

echo "=== 5. khoi phuc nguon ve tinh trang native (chot ban ship) ==="
# khong khoi phuc — patch la phan cua kernel #27 chinh thuc

echo "=== 6. hash ==="
md5sum "$OUT/boot.img"
sha256sum "$OUT/boot.img" "$OUT/parameter.txt"
