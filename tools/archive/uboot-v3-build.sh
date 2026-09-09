#!/bin/bash
# uboot-v3-build.sh — v3: console UART2 (pads XMIO) + tắt sdmmc/emmc + phím SARADC kênh 2
set -euo pipefail
SRC=/vol/uboot-v3-src
BLD=/vol/uboot-v3-build
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf-
cd /vol/uboot-src
git worktree remove --force "$SRC" 2>/dev/null || true
rm -rf "$SRC" "$BLD"
git worktree add "$SRC" 53cd91b73c
cd "$SRC"

echo "=== PATCH 1: defconfig DEBUG_UART_BASE -> uart2 0x20068000 ==="
sed -i 's/CONFIG_DEBUG_UART_BASE=0x20064000/CONFIG_DEBUG_UART_BASE=0x20068000/' configs/rk3128_defconfig
grep -n "DEBUG_UART_BASE" configs/rk3128_defconfig

echo "=== PATCH 2: evb.dts — uart2 okay, sdmmc/emmc disabled ==="
sed -i '/^&uart2 {/,/^};/ s/status = "disabled";/status = "okay";/' arch/arm/dts/rk3128-evb.dts
sed -i '/^&sdmmc {/,/^};/ s/status = "okay";/status = "disabled";/' arch/arm/dts/rk3128-evb.dts
if sed -n '/^&emmc {/,/^};/p' arch/arm/dts/rk3128-evb.dts | grep -q 'status ='; then
  sed -i '/^&emmc {/,/^};/ s/status = "okay";/status = "disabled";/' arch/arm/dts/rk3128-evb.dts
else
  sed -i '/^&emmc {/a\\tstatus = "disabled";' arch/arm/dts/rk3128-evb.dts
fi

echo "=== PATCH 3: stdout-path -> serial2 ==="
cat >> arch/arm/dts/rk3128-evb.dts <<'EOF'

/ {
	chosen {
		stdout-path = "serial2:115200n8";
	};
};
EOF

echo "=== PATCH 4: phím maskrom — SARADC kênh 1 -> 2 (kênh XMIO) ==="
sed -i 's/^#define RK3128_MASKROM_ADC_CH.*/#define RK3128_MASKROM_ADC_CH\t2/' board/rockchip/evb_rk3128/evb-rk3128.c

echo "=== KIEM TRA diff so voi base 53cd91b73c ==="
git --no-pager diff --stat
git --no-pager diff | head -80

echo "=== BUILD V3 ==="
export CROSS_COMPILE="$CROSS"
mkdir -p "$BLD"
make O="$BLD" rk3128_defconfig
make O="$BLD" -j"$(nproc)"
echo "=== BUILD V3 OK ==="
grep -ao 'U-Boot 20[0-9.]*[0-9a-zA-Z .:-]*' "$BLD/u-boot.bin" | head -1
ls -l "$BLD/u-boot.bin"

echo "=== VERIFY DTB NHUNG ==="
"$BLD/tools/dtc" -I dtb -O dts -o /tmp/v3.dts "$BLD/u-boot.dtb" 2>/dev/null || dtc -I dtb -O dts -o /tmp/v3.dts "$BLD/u-boot.dtb"
grep -n -A3 'uart@20068000' /tmp/v3.dts | head -8
grep -n -A2 'chosen' /tmp/v3.dts | head -6
grep -n -A3 'sdmmc@\|emmc@' /tmp/v3.dts | grep -B1 -A2 'status' | head -14

echo "=== PACK V3 ==="
rm -f "$BLD/uboot-v3.img"
/vol/rkbin/tools/loaderimage --pack --uboot "$BLD/u-boot.bin" "$BLD/uboot-v3.img" 0x60000000
ls -l "$BLD/uboot-v3.img"
md5sum "$BLD/uboot-v3.img" "$BLD/u-boot.bin" "$BLD/u-boot.dtb"
