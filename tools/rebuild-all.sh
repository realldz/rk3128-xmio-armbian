#!/usr/bin/env bash
# rebuild-all.sh — tái tạo toàn bộ pipeline XMIO Armbian từ git clone đến images.
# Chạy TRONG container rk3128-build (tham khảo tools/rebuild-all.sh chạy từ host).
#   docker run --rm -v rk3128-build-vol:/vol -v "$PWD:/workspace" --privileged \
#     rk3128-build bash /workspace/tools/rebuild-all.sh
set -euo pipefail
VOL=/vol
SRC=/workspace/repos/linux-kernel-6.6-rk3128-tvbox
A26=/workspace/A26-release-20260430/A26-release-20260430
OUT=/workspace/output
KREL=6.6.89-rk3128+

echo "=== [0/6] Toolchain + build script ==="
if [ ! -x "$VOL/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-gcc" ]; then
  mkdir -p "$VOL/toolchain"
  tar -xJf /workspace/tools/toolchain/gcc-arm-10.3.tar.xz -C "$VOL/toolchain"
fi
mkdir -p "$VOL/scripts"
cp -f /workspace/tools/build_kernel.sh "$VOL/scripts/build_kernel.sh"
chmod +x "$VOL/scripts/build_kernel.sh"

echo "=== [1/6] Kernel source (git archive, LF-forced) ==="
if [ ! -f /workspace/work/kernel-src.tar.gz ]; then
  git -C "$SRC" -c core.autocrlf=false -c core.eol=lf archive \
      --format=tar.gz -o /workspace/work/kernel-src.tar.gz HEAD
fi
if [ ! -f "$VOL/kernel-src/Makefile" ]; then
  rm -rf "$VOL/kernel-src"; mkdir -p "$VOL/kernel-src"
  tar -xzf /workspace/work/kernel-src.tar.gz -C "$VOL/kernel-src"
fi

echo "=== [2/6] Build kernel (deb) ==="
rm -rf "$VOL/kernel-build" "$VOL/kernel-out"
KERNEL_DIR="$VOL/kernel-src" RK_BUILD_DIR="$VOL/kernel-build" \
RK_OUT_DIR="$VOL/kernel-out" RK_DTS=rk3128-xmio LOCALVERSION=+ \
  bash "$VOL/scripts/build_kernel.sh" deb > /workspace/work/rebuild-kernel.log 2>&1
tail -12 /workspace/work/rebuild-kernel.log

echo "=== [3/6] Repack rootfs (NAND) ==="
mkdir -p "$VOL/kernel-out/final"
cp -f "$VOL/kernel-out"/linux-image-6.6.89-rk3128+_*.deb "$VOL/kernel-out/final/" 2>/dev/null || true
cp -f "$VOL/kernel-out"/linux-headers-6.6.89-rk3128+_*.deb "$VOL/kernel-out/final/" 2>/dev/null || true
cp -f "$VOL/kernel-out"/linux-libc-dev_*-2_armhf.deb "$VOL/kernel-out/final/" 2>/dev/null || true
bash /workspace/tools/repack-rootfs.sh "$VOL/kernel-out/final" armbian_rootfs_26.2_xmio.img \
  > /workspace/work/rebuild-rootfs.log 2>&1
tail -6 /workspace/work/rebuild-rootfs.log

echo "=== [4/6] Baseline DTB + SD image ==="
D=arch/arm/boot/dts/rockchip
cd "$VOL/kernel-src"
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
  -I include -I scripts/dtc/include-prefixes -I "$D" -I "$D/overlay" \
  "$D/rk3128-linux.dts" -o /tmp/linux.pp.dts
dtc -@ -O dtb -o /workspace/work/rk3128-linux.dtb /tmp/linux.pp.dts 2>/dev/null

bash /workspace/tools/make-sd-image.sh \
  "$OUT/armbian_rootfs_26.2_xmio.img" "$OUT/xmio-sd-2g.img" 2048 \
  > /workspace/work/rebuild-sd.log 2>&1
tail -4 /workspace/work/rebuild-sd.log

echo "=== [5/6] Embed fallback DTB + xmio-collect + boot.scr hook ==="
mkdir -p /mnt/nand /mnt/sd
mount -o loop,rw "$OUT/armbian_rootfs_26.2_xmio.img" /mnt/nand
install -m 0644 /workspace/work/rk3128-linux.dtb /mnt/nand/boot/dtb/rk3128-linux.dtb
install -m 0755 /workspace/tools/xmio-collect.sh /mnt/nand/usr/local/bin/xmio-collect
cp -f /workspace/tools/boot-patch/boot.cmd /mnt/nand/boot/boot.cmd
cp -f /workspace/tools/boot-patch/boot.scr /mnt/nand/boot/boot.scr
sync; umount /mnt/nand
LOOP=$(losetup --find --show --offset 16777216 "$OUT/xmio-sd-2g.img")
mount -o rw "$LOOP" /mnt/sd
install -m 0644 /workspace/work/rk3128-linux.dtb /mnt/sd/boot/dtb/rk3128-linux.dtb
install -m 0755 /workspace/tools/xmio-collect.sh /mnt/sd/usr/local/bin/xmio-collect
cp -f /workspace/tools/boot-patch/boot.cmd /mnt/sd/boot/boot.cmd
cp -f /workspace/tools/boot-patch/boot.scr /mnt/sd/boot/boot.scr
sync; umount /mnt/sd; losetup -d "$LOOP"

echo "=== [6/6] Collect deliverables + checksums ==="
mkdir -p "$OUT/debs" "$OUT/dtb/overlay" "$OUT/kernel" "$OUT/nand-flash"
cp -f "$VOL/kernel-out/final"/*.deb "$OUT/debs/"
cp -f "$VOL/kernel-out"/kernel.config "$VOL/kernel-out"/kernel.release "$OUT/kernel/"
cp -f "$VOL/kernel-build/arch/arm/boot/zImage" "$OUT/kernel/"
for f in "$VOL/kernel-out"/overlay/*.dtbo; do cp -f "$f" "$OUT/dtb/overlay/"; done
KIMG=$(find "$VOL/kernel-out/final" -name 'linux-image-6.6.89-rk3128+_*.deb' | head -1)
dpkg-deb -x "$KIMG" /tmp/kimg
cp -f /tmp/kimg/boot/dtb/rk3128-xmio.dtb "$OUT/dtb/"
cp -f "$A26/parameter.txt" "$A26/uboot.img" "$A26/trust.img" \
      "$A26/rk3128_loader_v2.12.263.bin" "$OUT/nand-flash/"
( cd "$OUT" && sha256sum armbian_rootfs_26.2_xmio.img xmio-sd-2g.img debs/*.deb \
    dtb/rk3128-xmio.dtb dtb/rk3128-linux.dtb dtb/overlay/*.dtbo kernel/zImage \
    nand-flash/* > SHA256SUMS.txt )

echo "=== REBUILD_ALL_DONE ==="
ls -la "$OUT"
