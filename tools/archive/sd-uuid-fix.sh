#!/usr/bin/env bash
exec > /workspace/work/sd-uuid-fix.log 2>&1
set -e
mkdir -p /mnt/s
L=$(losetup --find --show --offset 16777216 /workspace/output/xmio-sd-2g.img)
NEWUUID=$(tune2fs -l "$L" | awk '/Filesystem UUID:/ {print $3}')
echo "new SD fs UUID: $NEWUUID"
mount -o rw "$L" /mnt/s
sed -i "s/UUID=[0-9a-f-]*/UUID=$NEWUUID/" /mnt/s/etc/fstab
echo "--- fstab now ---"
cat /mnt/s/etc/fstab
sync; umount /mnt/s; losetup -d "$L"
echo SD_UUID_FIX_DONE
