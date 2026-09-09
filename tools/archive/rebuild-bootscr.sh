#!/usr/bin/env bash
exec > /workspace/work/bootscr-rebuild.log 2>&1
set -e
cd /workspace/work
# Repack boot.cmd into legacy uImage script (params must match original header:
# os=Linux arch=ARM type=Script comp=none, load/ep=0, name "Armbian boot script...")
mkimage -A arm -O linux -T script -C none -a 0 -e 0 \
  -n "Armbian boot script for RK3128 boxes" \
  -d boot.cmd boot.scr-xmio
file boot.scr-xmio
echo "=== hook present in script data? ==="
tail -c +65 boot.scr-xmio | grep -c xmio_fdt_override
echo "=== data size sanity (expect ~10430 = 9949+overhead lines) ==="
stat -c %s boot.scr-xmio
mkdir -p /workspace/tools/boot-patch
cp boot.cmd /workspace/tools/boot-patch/boot.cmd
cp boot.scr-xmio /workspace/tools/boot-patch/boot.scr
echo BOOTSCR_REBUILD_DONE
