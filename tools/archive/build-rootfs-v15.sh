#!/usr/bin/env bash
# build-rootfs-v15.sh — rebuild a clean Armbian rootfs for the XMIO RK3128
# (Plan B, NAND /dev/rknand_root) around the CURRENT v14 kernel build.
#
# Why v15: on-device fsck proved the previously flashed rootfs copy was
# corrupted in the NAND write path (host copies pass e2fsck -fn clean).
# v15 hardening:
#   - modules taken from the live v14 kernel build (exact match with
#     the zImage inside boot.img), installed via modules_install
#   - ext4 journal DISABLED (tune2fs -O ^has_journal): on this vendor
#     FTL the stale-journal corruption is exactly what bricked boot;
#     a no-journal root fsck -fy fixes cleanly at first boot instead
#   - full e2fsck -fy pass INSIDE the image before shipping (ship-clean)
#   - /etc/fstab: / entry removed (root already mounted by initramfs;
#     wrong-UUID fstab entries drop systemd into emergency)
#   - serial-getty@ttyS0 enabled -> login prompt on the UART console
#   - rk3128-xmio.dtb + config/System.map placed in /boot
#
# Run INSIDE docker rk3128-build (privileged, loop mounts):
#   bash /workspace/tools/build-rootfs-v15.sh
set -euo pipefail

SRC_IMG=/workspace/A26-release-20260430/A26-release-20260430/armbian_rootfs_26.2.img
OUT_IMG=/workspace/output/armbian_rootfs_v15_xmio.img
WORK_IMG=/workspace/work/armbian_rootfs_v15_xmio.img
MNT=/mnt/rootfs-v15
B=/vol/kernel-build
KREL="6.6.89-rk3128+"
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 0. fresh copy of the base A26 rootfs ==="
mkdir -p /workspace/work "$MNT"
cp -f "$SRC_IMG" "$WORK_IMG"

cleanup() { umount "$MNT" 2>/dev/null || true; }
trap cleanup EXIT

echo "=== 1. mount ==="
mount -o loop "$WORK_IMG" "$MNT"

echo "=== 2. drop old kernel artifacts ==="
rm -rf "$MNT/lib/modules/${KREL}"
rm -f  "$MNT/boot/vmlinuz-${KREL}" "$MNT/boot/System.map-${KREL}" \
       "$MNT/boot/config-${KREL}"

echo "=== 3. install modules from the live v14 build ==="
make -C /vol/kernel-src O="$B" ARCH=arm CROSS_COMPILE="$CROSS" \
  INSTALL_MOD_PATH="$MNT" modules_install \
  > /workspace/work/v15-modules.log 2>&1
tail -2 /workspace/work/v15-modules.log
test -d "$MNT/lib/modules/${KREL}"

echo "=== 4. /boot content ==="
cp -f "$B/arch/arm/boot/zImage" "$MNT/boot/vmlinuz-${KREL}"
cp -f "$B/System.map"           "$MNT/boot/System.map-${KREL}"
cp -f "$B/.config"              "$MNT/boot/config-${KREL}"
mkdir -p "$MNT/boot/dtb"
cp -f /workspace/output/planb-stock-uboot/rk3128-xmio-planb.dtb \
      "$MNT/boot/dtb/rk3128-xmio.dtb"

echo "=== 5. fstab: rely on initramfs-mounted root ==="
echo "--- current fstab ---"
cat "$MNT/etc/fstab" || true
cat > "$MNT/etc/fstab" <<'EOF'
# XMIO rk3128 (Plan B / NAND): root is mounted by the initramfs from
# /dev/rknand_root (see kernel cmdline). No / entry on purpose.
tmpfs /tmp tmpfs defaults,nosuid 0 0
EOF

echo "=== 6. serial console getty on ttyS0 ==="
mkdir -p "$MNT/etc/systemd/system/getty.target.wants"
ln -sfn /lib/systemd/system/serial-getty@.service \
        "$MNT/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service"

echo "=== 7. build info ==="
cat > "$MNT/etc/xmio-kernel-build.txt" <<EOF
XMIO RK3128 Armbian v15 (Plan B / NAND)
Kernel: ${KREL} (v14 build: clk_disable_unused kept-alive fix + diag)
Rootfs: A26 26.2 base, journal OFF (FTL-safe), fstab minimal
Getty: serial-getty@ttyS0 (UART0 115200)
Built: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "=== 8. unmount ==="
umount "$MNT"
trap - EXIT

echo "=== 9. ship-clean fsck + journal off (on the image file) ==="
tune2fs -O ^has_journal "$WORK_IMG"
e2fsck -fy "$WORK_IMG" > /workspace/work/v15-fsck.log 2>&1 || {
  echo "FATAL: e2fsck still failed:"; tail -20 /workspace/work/v15-fsck.log; exit 1; }
e2fsck -fn "$WORK_IMG" 2>&1 | tail -2
e2fsck -fn "$WORK_IMG" 2>&1 | grep -v Pass | tail -1

echo "=== 10. publish ==="
mv -f "$WORK_IMG" "$OUT_IMG"
ls -la "$OUT_IMG"
sha256sum "$OUT_IMG" | tee "${OUT_IMG}.sha256"
echo ROOTFS_V15_DONE
