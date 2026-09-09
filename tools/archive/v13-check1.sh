#!/usr/bin/env bash
exec > /workspace/work/v13-check1.log 2>&1
OUT=/workspace/output/planb-stock-uboot

echo "===== markers inside the PACKED v12 initrd.img.gz ====="
rm -rf /tmp/check-initrd && mkdir -p /tmp/check-initrd
gzip -dc "$OUT/initrd.img.gz" | cpio -idm -D /tmp/check-initrd 2>/dev/null
grep -n "INITRD-DIAG" /tmp/check-initrd/scripts/init-top/udev
grep -n "INITRD-DIAG" /tmp/check-initrd/init | head
ls -la /tmp/check-initrd/lib/udev/rules.d/59-rknand-noblkid.rules

echo "===== /init: init-top region verbatim ====="
grep -n -B2 -A2 "run_scripts /scripts/init-top" /tmp/check-initrd/init

echo "===== udev script verbatim ====="
cat /tmp/check-initrd/scripts/init-top/udev
echo V13_CHECK1_DONE
