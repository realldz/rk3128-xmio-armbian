#!/usr/bin/env bash
# v24.4b2-rootfs.sh — v23.2 tu v23 GOC + inject 4 file (tranh collision debugfs)
set -euo pipefail
OUT=/workspace/output/planb-stock-uboot
W=/workspace/work/vmrootfs
IMG_OLD=/workspace/output/armbian_rootfs_v23_xmio.img
IMG=/workspace/output/armbian_rootfs_v23.2_xmio.img

echo "=== 1. v23 GOC -> v23.2 ==="
rm -f "$IMG"
cp "$IMG_OLD" "$IMG"
sync; sleep 1

echo "=== 2. inject 4 file ==="
debugfs -w -R "write $OUT/onbox/vendor-mac /usr/local/sbin/vendor-mac" "$IMG"
debugfs -w -R "write $W/vendor-mac-apply /usr/local/sbin/vendor-mac-apply" "$IMG"
debugfs -w -R "write $W/vendor-mac.service /etc/systemd/system/vendor-mac.service" "$IMG"
debugfs -w -R "sif /usr/local/sbin/vendor-mac mode 0100755" "$IMG"
debugfs -w -R "sif /usr/local/sbin/vendor-mac-apply mode 0100755" "$IMG"
debugfs -w -R "sif /etc/systemd/system/vendor-mac.service mode 0100644" "$IMG"
debugfs -w -R "mkdir /etc/systemd/system/sysinit.target.wants" "$IMG" 2>/dev/null || true
debugfs -w -R "symlink /etc/systemd/system/sysinit.target.wants/vendor-mac.service /etc/systemd/system/vendor-mac.service" "$IMG"
sync; sleep 1

echo "=== 3. verify (script MOI phai co 'toi da 60s') ==="
debugfs -R "cat /usr/local/sbin/vendor-mac-apply" "$IMG" | head -3
debugfs -R "cat /usr/local/sbin/vendor-mac-apply" "$IMG" | grep -c "toi da 60s"
debugfs -R "stat /usr/local/sbin/vendor-mac-apply" "$IMG" | grep Mode
debugfs -R "stat /usr/local/sbin/vendor-mac" "$IMG" | grep Mode
debugfs -R "stat /etc/systemd/system/sysinit.target.wants/vendor-mac.service" "$IMG" | grep -E 'Type|Fast link name|name'

echo "=== 4. md5 ==="
md5sum "$IMG"
echo V23_2_DONE
