#!/bin/sh
# build-update-img.sh — pack Armbian one-click update.img giong Android stock
# Components: stock loader/uboot/misc/baseparamer + planb parameter/resource/boot + armbian rootfs v23.2
set -e

AFPTOOL=/tmp/rk2918_tools/afptool
IMGMAKER=/tmp/rk2918_tools/img_maker
OUT=/workspace/output/planb-stock-uboot
PACK=/tmp/apack

ROOTSIZE=0x00300000   # 1.5GB explicit cho partition root (rootfs 1.08GB + margin)

echo "=== 1. Staging pack dir ==="
rm -rf $PACK && mkdir -p $PACK
cd $PACK

# loader (giu nguyen stock — ban copy trong output, sha256 line 11 trong SHA256SUMS)
cp "$OUT/rk3128MiniLoaderAll(L)_V2.25_ink.bin" .
# uboot / misc / baseparamer / resource / boot — bo production hien tai
cp $OUT/uboot-stock.img      ./uboot.img
cp $OUT/misc.img             ./misc.img
cp $OUT/baseparamer-720P.img ./baseparamer-720P.img
cp $OUT/resource.img         ./resource.img
cp $OUT/boot.img             ./boot.img
# rootfs — DA copy vao container /tmp/rootfs-v232.img (tranh Windows lock lam
# afptool fread fail im lang; assert md5 truoc khi pack)
ROOTFS=/tmp/rootfs-v232.img
EXPECTED_MD5=657da568d2a31ae1676eda78a63091b9
echo "=== 0. rootfs md5 assert ==="
ACTUAL_MD5=$(md5sum $ROOTFS | cut -d' ' -f1)
if [ "$ACTUAL_MD5" != "$EXPECTED_MD5" ]; then
  echo "FATAL: rootfs md5 mismatch: $ACTUAL_MD5 != $EXPECTED_MD5"; exit 1
fi
echo "rootfs md5 OK: $ACTUAL_MD5"
cp $ROOTFS ./armbian_rootfs_v23.2_xmio.img

# parameter = force720, doi root "-@" -> explicit size
cp $OUT/parameter.txt.force720 ./parameter
sed -i "s/-@0x00017000(root)/${ROOTSIZE}@0x00017000(root)/" ./parameter

# scripts no-op (stock scripts tham chieu partition Android khong ton tai trong layout native)
printf '#!enable_script\nprint "\\nArmbian firmware update complete\\n"\n' > update-script
printf '#!enable_script\nprint "\\nArmbian firmware update complete\\n"\n' > recover-script

# package-file
cat > package-file <<'PFEOT'
# NAME		Relative path
package-file	package-file
bootloader	rk3128MiniLoaderAll(L)_V2.25_ink.bin
parameter	parameter
uboot		uboot.img
misc		misc.img
baseparamer	baseparamer-720P.img
resource	resource.img
boot		boot.img
root		armbian_rootfs_v23.2_xmio.img
update-script	update-script
recover-script	recover-script
PFEOT

echo "--- parameter CMDLINE root entry ---"
grep -o 'root)\|0x00300000@0x00017000(root)' parameter | head -2

echo "=== 2. afptool pack ==="
$AFPTOOL -pack . /tmp/armbian-afp.img 2>&1 | tail -12

echo "=== 3. img_maker (RKFW wrap) ==="
$IMGMAKER "$OUT/rk3128MiniLoaderAll(L)_V2.25_ink.bin" /tmp/armbian-afp.img $OUT/update_armbian_v28-v232.img

echo "=== 4. Sizes + hashes ==="
ls -la /tmp/armbian-afp.img $OUT/update_armbian_v28-v232.img
md5sum /tmp/armbian-afp.img $OUT/update_armbian_v28-v232.img
