#!/usr/bin/env bash
# v24.4c-build2.sh — rebuild sau khi fix warn_unused_result + pack boot
set -euo pipefail
B=/vol/kernel-build
OUT=/workspace/output/planb-stock-uboot
export CROSS_COMPILE=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf- ARCH=arm LOCALVERSION=+

echo "=== rebuild zImage #26 ==="
cd /vol/kernel-src
make -j"$(nproc)" O="$B" zImage > /workspace/work/v24.4c-build.log 2>&1 || {
  tail -40 /workspace/work/v24.4c-build.log; exit 1; }
tail -2 /workspace/work/v24.4c-build.log
strings "$B/vmlinux" | grep -c "not ready after 30s"
if strings "$B/vmlinux" | grep -q "not ready after %ums"; then
  echo "ERROR: old blocking string still present"; exit 1
fi
echo "old string gone OK"
md5sum "$B/arch/arm/boot/zImage"

echo "=== pack boot v24.4c ==="
[ -f /workspace/output/archive/boot-v24.4b.img ] || cp "$OUT/boot.img" /workspace/output/archive/boot-v24.4b.img
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
md5sum "$OUT/boot.img"
echo V244C_DONE
