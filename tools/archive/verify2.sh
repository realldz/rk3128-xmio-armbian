#!/usr/bin/env bash
exec > /workspace/work/verify2.log 2>&1
A26=/workspace/A26-release-20260430/A26-release-20260430
echo "=== idbloader byte-identity check (first 109484 bytes of SD image vs A26 idbloader.img) ==="
head -c 109484 /workspace/output/xmio-sd-2g.img | sha256sum
sha256sum $A26/idbloader.img
echo "=== uboot/trust byte-identity (first 4194304 bytes of SD image vs A26) ==="
tail -c +$((16384*512+1)) /workspace/output/xmio-sd-2g.img | head -c 4194304 | sha256sum
sha256sum $A26/uboot.img
tail -c +$((24576*512+1)) /workspace/output/xmio-sd-2g.img | head -c 4194304 | sha256sum
sha256sum $A26/trust.img
echo "=== SHA256SUMS for all deliverables ==="
cd /workspace/output
sha256sum armbian_rootfs_26.2_xmio.img xmio-sd-2g.img debs/*.deb dtb/rk3128-xmio.dtb kernel/zImage nand-flash/* > SHA256SUMS.txt
cat SHA256SUMS.txt
echo DONE2
