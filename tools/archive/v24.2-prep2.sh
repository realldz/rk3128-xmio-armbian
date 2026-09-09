#!/usr/bin/env bash
# v24.2-prep2.sh — node cpuinfo chuan vendor + doan rk3128 trong driver
set -uo pipefail
cd /vol/kernel-src

echo "=== 1. rk312x-android.dtsi: node cpuinfo chuan ==="
grep -B3 -A12 'rockchip,cpuinfo' arch/arm/boot/dts/rockchip/rk312x-android.dtsi

echo
echo "=== 2. rk3128.dtsi (vendor): efuse cells day du ==="
EF=$(grep -rln 'rk3128-efuse' arch/arm/boot/dts/rockchip/rk312*.dtsi | head -1)
echo "file: $EF"
sed -n '/efuse@20090000/,/};/p' "$EF" | head -40

echo
echo "=== 3. rockchip-cpuinfo.c doan rieng rk3128 (280-360) ==="
sed -n '280,360p' drivers/soc/rockchip/rockchip-cpuinfo.c

echo
echo "=== 4. root compatible trong DTB cua ta ==="
head -8 /workspace/work/xmio-planb-v23.dts

echo
echo "=== 5. GENERIC_DT machine co init_time gi? ==="
sed -n '190,210p' arch/arm/kernel/devtree.c