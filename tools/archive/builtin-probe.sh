#!/usr/bin/env bash
exec > /workspace/work/builtin-probe.log 2>&1
set -e
mkdir -p /mnt/n /tmp/uird2 /work-extract
L=$(losetup --find --show /workspace/output/armbian_rootfs_26.2_xmio.img)
mount -o ro "$L" /mnt/n
cd /tmp/uird2 && rm -rf *
tail -c +65 /mnt/n/boot/uInitrd-6.6.89-rk3128+ | zcat 2>/dev/null > data.cpio || cp data.gz data.cpio
if [ ! -s data.cpio ]; then echo "zcat failed, trying cpio direct"; tail -c +65 /mnt/n/boot/uInitrd-6.6.89-rk3128+ > data.bin; fi
cpio -idm --no-absolute-filenames "usr/lib/modules/6.6.89-rk3128+/modules.builtin.modinfo" < data.cpio 2>&1 | tail -2
B="usr/lib/modules/6.6.89-rk3128+/modules.builtin.modinfo"
ls -la "$B" 2>/dev/null
echo "=== rknand builtin modinfo entries ==="
tr '\0' '\n' < "$B" | grep -i 'rknand' | head -20
echo "=== rkflash builtin modinfo ==="
tr '\0' '\n' < "$B" | grep -iE 'rkflash|sftl' | head -10
echo "=== builtin module count ==="
tr '\0' '\n' < "$B" | grep -c '\.ko'
umount /mnt/n; losetup -d "$L"
echo BUILTIN_PROBE_DONE
