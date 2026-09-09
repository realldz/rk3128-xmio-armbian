#!/bin/bash
# uboot-v5-build.sh — BẢN CUỐI: v4 patches + linaro 6.3.1 + ADC_MAX 1000 (mọi phím đều ăn)
set -euo pipefail
SRC=/vol/uboot-v3-src          # worktree đã có 4 patch (uart2/sdmmc/stdout/adc-ch2)
BLD=/vol/uboot-v5-build
export CROSS_COMPILE=/vol/toolchain-linaro/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-

cd "$SRC"
echo "=== PATCH 5: ADC_MAX 30 -> 1000 (mọi phímXMIO 0-911 raw deu trigger; tha = 1023) ==="
sed -i 's/^#define RK3128_MASKROM_ADC_MAX.*/#define RK3128_MASKROM_ADC_MAX\t1000/' board/rockchip/evb_rk3128/evb-rk3128.c
grep -n "RK3128_MASKROM_ADC" board/rockchip/evb_rk3128/evb-rk3128.c | head -4
git --no-pager diff --stat | tail -3

echo "=== BUILD V5 (linaro 6.3.1) ==="
rm -rf "$BLD"
make O="$BLD" rk3128_defconfig
make O="$BLD" -j"$(nproc)"
echo "=== BUILD V5 OK ==="
grep -ao 'U-Boot 20[0-9.]*[0-9a-zA-Z .:-]*' "$BLD/u-boot.bin" | head -1
ls -l "$BLD/u-boot.bin"

echo "=== KIEM TRA DTB NHUNG TRONG u-boot.bin (phai co DTB append cuoi) ==="
SZ=$(stat -c%s "$BLD/u-boot.bin"); DTBSZ=$(stat -c%s "$BLD/u-boot.dtb")
echo "u-boot.bin=$SZ u-boot.dtb=$DTBSZ (bin phai >= dtb; A26 payload 839104 = code 815416 + dtb 23681)"
tail -c "$DTBSZ" "$BLD/u-boot.bin" | md5sum
md5sum "$BLD/u-boot.dtb"

echo "=== PACK V5 ==="
rm -f "$BLD/uboot-v5.img"
/vol/rkbin/tools/loaderimage --pack --uboot "$BLD/u-boot.bin" "$BLD/uboot-v5.img" 0x60000000
ls -l "$BLD/uboot-v5.img"
mkdir -p /workspace/output/planb-uboot-v5
cp "$BLD/uboot-v5.img" "$BLD/u-boot.bin" "$BLD/u-boot.dtb" "$BLD/.config" /workspace/output/planb-uboot-v5/
cd /workspace/output/planb-uboot-v5
mv u-boot.bin u-boot-v5.bin
mv u-boot.dtb u-boot-v5.dtb
mv .config uboot-v5.config
md5sum *
