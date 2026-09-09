#!/usr/bin/env bash
exec > /workspace/work/v19-analysis2.log 2>&1
echo '=== gpio-leds nodes anywhere in tree dts ==='
grep -rln 'gpio-leds' /vol/kernel-src/arch/arm/boot/dts/ 2>/dev/null | head -8
echo
echo '=== example: read one gpio-leds dts (rk3288-miniarm or similar) ==='
for f in $(grep -rln 'gpio-leds' /vol/kernel-src/arch/arm/boot/dts/rockchip/ 2>/dev/null | head -2); do
  echo "--- $f ---"
  grep -A12 'gpio-leds' "$f" | head -18
done
echo
echo '=== disk-activity trigger available in this kernel? ==='
ls /vol/kernel-src/drivers/leds/trigger/ | grep -E 'disk|blk'
grep -E 'CONFIG_LEDS_TRIGGER_DISK|CONFIG_LEDS_TRIGGER_HEARTBEAT|CONFIG_LEDS_TRIGGER_ACTIVITY' /vol/kernel-build/.config
echo
echo '=== does ledtrig-disk hook block layer (check Makefile + source exists) ==='
grep -n 'ledtrig-disk' /vol/kernel-src/drivers/leds/trigger/Makefile
