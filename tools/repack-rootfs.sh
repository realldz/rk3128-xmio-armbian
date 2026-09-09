#!/usr/bin/env bash
# Repack the A26 Armbian rootfs with a newly built kernel (linux-image deb)
# for the XMIO RK3128 board. Run inside the rk3128-build container with:
#   /workspace mounted, --privileged (loop mounts), and the docker volume
#   containing the fresh .deb files.
#
# Usage: repack-rootfs.sh <deb-dir-in-volume> [out-name]
set -euo pipefail

DEB_DIR="${1:?usage: repack-rootfs.sh <deb-dir> [out-name]}"
OUT_NAME="${2:-armbian_rootfs_26.2_xmio.img}"
SRC_IMG="/workspace/A26-release-20260430/A26-release-20260430/armbian_rootfs_26.2.img"
WORK_IMG="/workspace/work/${OUT_NAME}"
MNT=/mnt/rootfs

KREL="6.6.89-rk3128+"

echo "=== Copy base rootfs image ==="
mkdir -p /workspace/work /mnt/rootfs
cp -f "${SRC_IMG}" "${WORK_IMG}"

echo "=== Mount rootfs ==="
mount -o loop "${WORK_IMG}" "${MNT}"

cleanup() {
    umount "${MNT}" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Remove old kernel artifacts ==="
rm -rf "${MNT}/lib/modules/${KREL}"
rm -f  "${MNT}/boot/vmlinuz-${KREL}" "${MNT}/boot/System.map-${KREL}" \
       "${MNT}/boot/config-${KREL}"
rm -rf "${MNT}/boot/dtb" "${MNT}/boot/dtb-${KREL}"
# keep uInitrd/initrd.img (same kernelrelease -> still valid)

echo "=== Install new kernel debs (data extraction) ==="
for deb in "${DEB_DIR}"/linux-image-*.deb; do
    echo "  extracting $(basename "$deb")"
    dpkg-deb -x "$deb" "${MNT}"
done
for deb in "${DEB_DIR}"/linux-headers-*.deb "${DEB_DIR}"/linux-libc-dev_*.deb; do
    [ -e "$deb" ] || continue
    echo "  extracting $(basename "$deb")"
    dpkg-deb -x "$deb" "${MNT}"
done

echo "=== Fix module tree symlinks ==="
if [ -d "${MNT}/usr/src/linux-headers-${KREL}" ]; then
    mkdir -p "${MNT}/lib/modules/${KREL}"
    ln -sfn "/usr/src/linux-headers-${KREL}" "${MNT}/lib/modules/${KREL}/build"
    ln -sfn "/usr/src/linux-headers-${KREL}" "${MNT}/lib/modules/${KREL}/source" || true
fi

echo "=== depmod ==="
depmod -b "${MNT}" "${KREL}"

echo "=== Sanity check ==="
test -f "${MNT}/boot/vmlinuz-${KREL}"
test -f "${MNT}/boot/dtb/rk3128-xmio.dtb" || {
    echo "ERROR: rk3128-xmio.dtb not found in /boot/dtb"; ls "${MNT}/boot/dtb"; exit 1; }
test -f "${MNT}/boot/dtb/overlay/rk3128-uart2.dtbo" || {
    echo "ERROR: rk3128-uart2.dtbo missing"; ls "${MNT}/boot/dtb/overlay"; exit 1; }

echo "=== Update armbianEnv.txt for XMIO ==="
cat > "${MNT}/boot/armbianEnv.txt" <<'EOF'
verbosity=1
extraargs=coherent_pool=2M console=ttyS2,115200 console=ttyS1,115200 console=tty1
bootlogo=false
overlay_prefix=rk3128
fdtfile=rk3128-xmio.dtb
overlays=usb-otg-host uart1 uart2 dmc-disabled wlan-esp8089
rootfstype=ext4
EOF
cat "${MNT}/boot/armbianEnv.txt"

echo "=== Record kernel build info ==="
cat > "${MNT}/etc/xmio-kernel-build.txt" <<EOF
XMIO RK3128 Armbian image
Kernel: ${KREL} (local build with rk3128-xmio.dts)
Base: A26 release 20260430 by chieunhatnang-personal
USB host VBUS: GPIO3_C4 hog (from stock DTB analysis)
Built: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "=== Unmount ==="
umount "${MNT}"
trap - EXIT

echo "=== Done: ${WORK_IMG} ==="
ls -la "${WORK_IMG}"
