#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. output/ tree with sizes ==="
du -ah /workspace/output/ 2>/dev/null | sort -rh | head -40
echo
echo "=== 2. full listing planb-stock-uboot ==="
ls -la /workspace/output/planb-stock-uboot/
ls -la /workspace/output/planb-stock-uboot/onbox/ 2>/dev/null
echo
echo "=== 3. top-level output ==="
ls -la /workspace/output/
ls -la /workspace/output/kernel /workspace/output/nand-flash 2>/dev/null
echo
echo "=== 4. bundle.sh: what does it pack? ==="
cat /workspace/tools/bundle.sh
echo
echo "=== 5. current boot.img md5 (v24.1?) + rootfs versions present ==="
md5sum /workspace/output/planb-stock-uboot/boot.img /workspace/output/planb-stock-uboot/resource.img /workspace/output/armbian_rootfs_v22_xmio.img 2>/dev/null
echo
echo "=== 6. parameter.native = active? diff vs others (short) ==="
md5sum /workspace/output/planb-stock-uboot/parameter.txt*
