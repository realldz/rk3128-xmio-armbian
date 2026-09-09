#!/usr/bin/env bash
# planb-v24.sh — kernel: /dev/vendor_storage luôn được register (kể cả khi
# FTL vendor scan fail) để userspace ghi MAC vào vendor storage (vùng
# reserved của FTL, ngoài mọi partition). DTB giữ v23.2 (label MAC) —
# vendor storage là tầng persist cho firmware khác.
set -euo pipefail

OUT=/workspace/output/planb-stock-uboot
SRC=/vol/kernel-src
B=/vol/kernel-build
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. patch rk_nand_blk.c ==="
python3 /workspace/tools/v24-kpatch.py

echo "=== 2. rebuild zImage ==="
cd "$SRC"
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make -j"$(nproc)" O="$B" zImage > /workspace/work/v24-build.log 2>&1 || {
  tail -40 /workspace/work/v24-build.log; exit 1; }
tail -3 /workspace/work/v24-build.log
strings "$B/vmlinux" | grep -q 'exposing vendor_storage ioctl node' && echo "patch string in vmlinux OK"

echo "=== 3. repack boot.img (DTB/resource giữ nguyên v23.2) ==="
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

echo "=== 4. build vendor-mac tool ==="
"$CROSS"gcc -O2 -Wall -static -o "$OUT/onbox/vendor-mac" /workspace/tools/v24-vendor-mac.c
"$CROSS"strip "$OUT/onbox/vendor-mac"
ls -la "$OUT/onbox/vendor-mac"

echo "=== 5. hashes + bundle ==="
cd "$OUT"
rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.v14diag.bak parameter.txt.v16.bak \
  parameter.txt.badnand1 parameter.txt.native uboot-stock.img uboot-planb-mac.img \
  misc.img baseparamer-720P.img resource.img resource-baseline.img boot.img \
  rk3128-xmio-planb.dtb "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
md5sum "$OUT/boot.img" "$OUT/onbox/vendor-mac"
echo PLANB_V24_DONE
