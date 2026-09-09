#!/usr/bin/env bash
# v24.4-rootfs.sh — build vendor-mac (show mode) + inject rootfs v23 -> v23.1
set -euo pipefail
OUT=/workspace/output/planb-stock-uboot
W=/workspace/work/vmrootfs
IMG_OLD=/workspace/output/armbian_rootfs_v23_xmio.img
IMG=/workspace/output/armbian_rootfs_v23.1_xmio.img
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. build vendor-mac static (show mode moi) ==="
"$CROSS"gcc -static -O2 -s -o "$OUT/onbox/vendor-mac" /workspace/tools/v24-vendor-mac.c
ls -la "$OUT/onbox/vendor-mac"
file "$OUT/onbox/vendor-mac" | head -1

echo "=== 2. copy rootfs v23 -> v23.1 ==="
rm -f "$IMG"
cp "$IMG_OLD" "$IMG"
sync; sleep 1
ls -la "$IMG"

echo "=== 3. inject vendor-mac + apply script + unit ==="
debugfs -w -R "write $OUT/onbox/vendor-mac /usr/local/sbin/vendor-mac" "$IMG"
debugfs -w -R "write $W/vendor-mac-apply /usr/local/sbin/vendor-mac-apply" "$IMG"
debugfs -w -R "write $W/vendor-mac.service /etc/systemd/system/vendor-mac.service" "$IMG"
debugfs -w -R "sif /usr/local/sbin/vendor-mac mode 0100755" "$IMG"
debugfs -w -R "sif /usr/local/sbin/vendor-mac-apply mode 0100755" "$IMG"
debugfs -w -R "sif /etc/systemd/system/vendor-mac.service mode 0100644" "$IMG"
debugfs -w -R "mkdir /etc/systemd/system/sysinit.target.wants" "$IMG" 2>/dev/null || true
debugfs -w -R "symlink /etc/systemd/system/sysinit.target.wants/vendor-mac.service /etc/systemd/system/vendor-mac.service" "$IMG"
sync; sleep 1

echo "=== 4. verify ==="
debugfs -R "stat /usr/local/sbin/vendor-mac" "$IMG" | grep -E 'Mode|Size'
debugfs -R "stat /usr/local/sbin/vendor-mac-apply" "$IMG" | grep -E 'Mode|Size'
debugfs -R "cat /usr/local/sbin/vendor-mac-apply" "$IMG" | head -6
echo "--- unit ---"
debugfs -R "cat /etc/systemd/system/vendor-mac.service" "$IMG" | head -4
echo "--- symlink ---"
debugfs -R "stat /etc/systemd/system/sysinit.target.wants/vendor-mac.service" "$IMG" | head -8
echo "--- binary binary-match? (cmp inject vs onbox) ---"
debugfs -R "dump /usr/local/sbin/vendor-mac /tmp/vm.check" "$IMG"
cmp "$OUT/onbox/vendor-mac" /tmp/vm.check && echo "BINARY MATCH"
rm -f /tmp/vm.check
sync; sleep 1

echo "=== 5. md5 ==="
md5sum "$IMG" "$IMG_OLD"
echo V244_ROOTFS_DONE
