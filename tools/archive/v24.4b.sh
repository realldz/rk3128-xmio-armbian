#!/usr/bin/env bash
# v24.4b.sh — kernel #25 (cap 20s) + rootfs v23.2 (service wait-loop 60s)
set -euo pipefail
OUT=/workspace/output/planb-stock-uboot
W=/workspace/work/vmrootfs
SRC=/vol/kernel-src
B=/vol/kernel-build

echo "=== 1. rebuild zImage (cap 20s) ==="
cd "$SRC"
export CROSS_COMPILE=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf- ARCH=arm LOCALVERSION=+
make -j"$(nproc)" O="$B" zImage > /workspace/work/v24.4b-build.log 2>&1 || {
  tail -40 /workspace/work/v24.4b-build.log; exit 1; }
tail -2 /workspace/work/v24.4b-build.log
md5sum "$B/arch/arm/boot/zImage"

echo "=== 2. rootfs v23.1 -> v23.2 (new apply script) ==="
cp -f /workspace/output/armbian_rootfs_v23.1_xmio.img /workspace/output/armbian_rootfs_v23.2_xmio.img
sync; sleep 1
IMG=/workspace/output/armbian_rootfs_v23.2_xmio.img
debugfs -w -R "write $W/vendor-mac-apply /usr/local/sbin/vendor-mac-apply" "$IMG"
debugfs -w -R "sif /usr/local/sbin/vendor-mac-apply mode 0100755" "$IMG"
sync; sleep 1
debugfs -R "cat /usr/local/sbin/vendor-mac-apply" "$IMG" | sed -n '4,6p'
debugfs -R "stat /usr/local/sbin/vendor-mac-apply" "$IMG" | grep Mode

echo "=== 3. backup + pack boot v24.4b ==="
if [ ! -f /workspace/output/archive/boot-v24.4a.img ]; then
  cp "$OUT/boot.img" /workspace/output/archive/boot-v24.4a.img
  md5sum /workspace/output/archive/boot-v24.4a.img
fi
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
psize = struct.unpack_from('<I', d, 36)[0]
ksize = struct.unpack_from('<I', d, 8)[0]
z = open('/vol/kernel-build/arch/arm/boot/zImage','rb').read()
assert d[psize:psize+ksize] == z, 'kernel mismatch!'
print('KERNEL MATCH OK')
EOF

echo "=== 4. md5 ==="
md5sum "$OUT/boot.img" /workspace/output/armbian_rootfs_v23.2_xmio.img
echo V244B_DONE
