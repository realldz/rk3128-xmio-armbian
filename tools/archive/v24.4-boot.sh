#!/usr/bin/env bash
# v24.4-boot.sh — pack boot.img v24.4 (zImage #24 + ramdisk/second giu nguyen)
# + bundle + checksums. Backup boot v24.3 (5f61edcd) truoc khi ghi de.
set -euo pipefail
OUT=/workspace/output/planb-stock-uboot
B=/vol/kernel-build

echo "=== 0. backup boot v24.3 ==="
if [ ! -f /workspace/output/archive/boot-v24.3.img ]; then
  mkdir -p /workspace/output/archive
  cp "$OUT/boot.img" /workspace/output/archive/boot-v24.3.img
  md5sum /workspace/output/archive/boot-v24.3.img
fi

echo "=== 1. pack boot v24.4 ==="
mkbootimg --kernel "$B/arch/arm/boot/zImage" \
  --ramdisk "$OUT/initrd.img.gz" \
  --second "$OUT/resource.img" \
  --base 0x60000000 --kernel_offset 0x00408000 \
  --ramdisk_offset 0x02000000 --second_offset 0x00F00000 \
  --tags_offset 0x00088000 --pagesize 16384 \
  --cmdline "" --output "$OUT/boot.img"

echo "=== 2. RAM layout overlap check ==="
python3 - <<'EOF'
import struct
d = open('/workspace/output/planb-stock-uboot/boot.img','rb').read()
f = struct.unpack_from('<8s10I', d, 0)
k0,k1,r0,r1,s0,s1 = f[2],f[2]+f[1],f[4],f[4]+f[3],f[6],f[6]+f[5]
def ov(a0,a1,b0,b1): return max(a0,b0)<min(a1,b1)
assert not ov(k0,k1,s0,s1) and not ov(k0,k1,r0,r1) and not ov(r0,r1,s0,s1)
print('RAM LAYOUT OK')
EOF

echo "=== 3. sanity: zImage moi co trong boot ==="
python3 - <<'EOF'
import struct, hashlib
d = open('/workspace/output/planb-stock-uboot/boot.img','rb').read()
ksize = struct.unpack_from('<I', d, 8)[0]
z = open('/vol/kernel-build/arch/arm/boot/zImage','rb').read()
print('kernel-in-boot:', hashlib.md5(d[4096:4096+ksize]).hexdigest()[:16],
      '| zImage:', hashlib.md5(z).hexdigest()[:16], '| match:',
      d[4096:4096+ksize] == z)
EOF

echo "=== 4. SHA256SUMS + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.native misc.img baseparamer-720P.img \
  uboot-stock.img resource.img boot.img rk3128-xmio-planb.dtb \
  initrd.img.gz "rk3128MiniLoaderAll(L)_V2.25_ink.bin" \
  onbox/vendor-mac onbox/xmio-led-arm onbox/xmio-led.service > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log

echo "=== 5. md5 san pham cuoi ==="
md5sum "$OUT/boot.img" "$OUT/resource.img" /workspace/output/armbian_rootfs_v23.1_xmio.img
echo V244_BOOT_DONE
