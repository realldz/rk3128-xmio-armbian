#!/bin/bash
# vendor-fix-plan.sh — kiem tra dk register vendor + tool + uboot-planb-mac
set -uo pipefail
KS=/vol/kernel-src
echo "### 1. rk_nand_blk.c quanh line 878 (dk goi rk_vendor_register):"
sed -n '850,895p' $KS/drivers/rk_nand/rk_nand_blk.c
echo
echo "### 2. rk_ftl_vendor_read/write + vendor storage init trong blob FTL (fail thi sao):"
grep -rn "vendor storage init\|rk_ftl_vendor_read\|rk_ftl_vendor_write" $KS/drivers/rk_nand/*.c | head -10
echo
echo "### 3. tool vendor-mac: usage syntax:"
sed -n '1,40p' /workspace/tools/v24-vendor-mac.c | grep -A15 -iE "usage|argv|main" | head -20
echo
echo "### 4. uboot-planb-mac.img ton tai? sha256?"
find /workspace/output /workspace/work -iname "*planb-mac*" -o -iname "*v23.3*" 2>/dev/null | head -5
for f in $(find /workspace/output /workspace/work -iname "*planb-mac*.img" 2>/dev/null | head -3); do
  sha256sum "$f" | cut -c1-16; ls -la "$f"
done
echo
echo "### 5. onbox/ co gi (tool da bake vao rootfs v23?):"
ls -la /workspace/output/planb-stock-uboot/onbox/ 2>/dev/null
grep -rn "vendor-mac" /workspace/work/rootfs-build* 2>/dev/null | head -3
find /workspace -maxdepth 3 -name "*.sh" -newer /workspace/output/planb-stock-uboot/parameter.txt.native 2>/dev/null | grep -iE "rootfs|v23" | head -5
