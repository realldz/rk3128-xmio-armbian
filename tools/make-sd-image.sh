#!/usr/bin/env bash
# Build a bootable SD-card image for XMIO RK3128 from a rootfs image.
# Usage (in privileged container):
#   make-sd-image.sh <rootfs.img> <out.img> [sizeMB]
set -euo pipefail

ROOTFS_SRC="${1:?usage: make-sd-image.sh <rootfs.img> <out.img> [sizeMB]}"
OUT_IMG="${2:?missing out.img}"
SIZE_MB="${3:-2048}"
A26_DIR="/workspace/A26-release-20260430/A26-release-20260430"

echo "=== Preparing ${OUT_IMG} (${SIZE_MB}MB) ==="
rm -f "${OUT_IMG}"
truncate -s "${SIZE_MB}M" "${OUT_IMG}"

echo "=== Partition table (MBR, part1 from 16MiB) ==="
parted -s "${OUT_IMG}" mklabel msdos
parted -s "${OUT_IMG}" mkpart primary ext4 16MiB 100%
# parted sets boot flag on part1 when instructed; not required for RK boot.

# Partition 1 starts at 16MiB (sector 32768) and runs to end of image.
PART_START=32768
TOTAL_SECTORS=$((SIZE_MB * 2048))
PART_SIZE=$((TOTAL_SECTORS - PART_START))
echo "part1 start=${PART_START} sectors (${PART_SIZE}s)"

echo "=== Writing bootchain ==="
dd if="${A26_DIR}/idbloader.img" of="${OUT_IMG}" bs=512 seek=64 conv=notrunc
dd if="${A26_DIR}/uboot.img"     of="${OUT_IMG}" bs=512 seek=16384 conv=notrunc
dd if="${A26_DIR}/trust.img"     of="${OUT_IMG}" bs=512 seek=24576 conv=notrunc

echo "=== Formatting rootfs partition ==="
LOOP=$(losetup --find --show --offset $((PART_START*512)) --sizelimit $((PART_SIZE*512)) "${OUT_IMG}")
trap 'losetup -d "$LOOP" 2>/dev/null || true; umount /mnt/sd-src 2>/dev/null || true; umount /mnt/sd-dst 2>/dev/null || true' EXIT
mkfs.ext4 -F -L armbi_root -O ^metadata_csum,^64bit "${LOOP}"

mkdir -p /mnt/sd-src /mnt/sd-dst
mount -o loop,ro "${ROOTFS_SRC}" /mnt/sd-src
mount "${LOOP}" /mnt/sd-dst

echo "=== Populating rootfs ==="
cp -a /mnt/sd-src/. /mnt/sd-dst/

# SD boots share UART2 pins with the SDMMC controller; drop the uart2 overlay
# from the SD variant so the kernel can talk to the card reader.
sed -i -E 's/^(overlays=.*) uart2( .*)?$/\1\2/; s/^(overlays=.*) uart2$/\1/' /mnt/sd-dst/boot/armbianEnv.txt
grep '^overlays=' /mnt/sd-dst/boot/armbianEnv.txt

# Distinct fs UUID + label so NAND and SD rootfs never collide in blkid
# (boot uses PARTUUID/root=, but distinct UUIDs keep e2fsck/mounts unambiguous).
SDUUID=$(tune2fs -l "${LOOP}" | awk '/Filesystem UUID:/ {print $3}')
tune2fs -U random -L armbiands "${LOOP}"
NEWSUUID=$(tune2fs -l "${LOOP}" | awk '/Filesystem UUID:/ {print $3}')
sed -i "s/UUID=${SDUUID}/UUID=${NEWSUUID}/" /mnt/sd-dst/etc/fstab
echo "SD fs UUID: ${NEWSUUID}"

sync
umount /mnt/sd-src /mnt/sd-dst
losetup -d "${LOOP}"
trap - EXIT

echo "=== Done: ${OUT_IMG} ==="
ls -la "${OUT_IMG}"
