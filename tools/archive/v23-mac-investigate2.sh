#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. rk3128 dts(i) in vendor tree ==="
ls /vol/kernel-src/arch/arm/boot/dts/ | grep -i 'rk312\|rk3036' | head -10
echo "=== 2. stock DTB: efuse / nvmem / mac ==="
for f in /workspace/work/stock-dtbs/*; do
  [ -f "$f" ] || continue
  echo "-- $f"
  strings "$f" | grep -iE 'efuse|nvmem|mac' | head -10
done
echo "=== 3. data-orig.txt (decompiled stock) efuse nodes ==="
grep -n -i -B3 -A14 'efuse' /workspace/work/data-orig.txt 2>/dev/null | head -60
echo "=== 4. rockchip-efuse.c rk3128 section ==="
sed -n '380,495p' /vol/kernel-src/drivers/nvmem/rockchip-efuse.c
echo "=== 5. any dts in tree with efuse + mac-address cell ==="
grep -rln 'rk3128-efuse\|rk3228-efuse' /vol/kernel-src/arch/arm/boot/dts/ 2>/dev/null | head -5
grep -rn -A8 'rockchip,rk3128-efuse' /vol/kernel-src/arch/arm/boot/dts/ 2>/dev/null | head -30
echo "=== 6. efuse reg base in any rk dtsi ==="
grep -rn -B2 -A6 'efuse@' /vol/kernel-src/arch/arm/boot/dts/rk3036*.dtsi /vol/kernel-src/arch/arm/boot/dts/rk32*.dtsi 2>/dev/null | head -30
