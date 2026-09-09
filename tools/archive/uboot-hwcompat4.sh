#!/bin/bash
# uboot-hwcompat4.sh — round-trip pack check + key node source + banner đối chiếu
set -uo pipefail
echo "############ 1. Round-trip: unpack uboot-v1.img -> so md5 voi u-boot.bin ############"
rm -rf /tmp/rt && mkdir /tmp/rt
/vol/rkbin/tools/loaderimage --unpack --uboot /vol/uboot-build/uboot-new.img /tmp/rt/u.bin 2>&1 | tail -1
md5sum /tmp/rt/u.bin /vol/uboot-build/u-boot.bin

echo
echo "############ 2. Key/dm-key trong source DTB rk3128-evb ############"
grep -n -i "key" /vol/uboot-src/dts/rk3128-evb.dts | head -12
echo "--- dm-key driver node format:"
grep -rn "dm-key\|adc-dm-key\|gpio-dm-key" /vol/uboot-src/dts/*.dts /vol/uboot-src/dts/rk32*.dts* 2>/dev/null | head -8

echo
echo "############ 3. banner trong payload A26 vs cua toi ############"
grep -ao 'U-Boot 20[0-9.]*[0-9a-zA-Z .:-]*' /tmp/rt/u.bin | head -1
grep -ao 'U-Boot 20[0-9.]*[0-9a-zA-Z .:-]*' /vol/uboot-build/unpack-a26/uboot-a26.bin | head -1

echo
echo "############ 4. header size/flag byte chinh xac (od offset 0x14-0x1F) ############"
echo "--- stock:"; od -A x -t x1 -j 16 -N 16 /workspace/work/stock-rkunpack/uboot.img
echo "--- A26:";   od -A x -t x1 -j 16 -N 16 /workspace/output/nand-flash/uboot.img
echo "--- v1:";    od -A x -t x1 -j 16 -N 16 /vol/uboot-build/uboot-new.img
