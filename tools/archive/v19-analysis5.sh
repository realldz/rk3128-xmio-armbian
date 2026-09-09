#!/usr/bin/env bash
exec > /workspace/work/v19-analysis5.log 2>&1
echo '=== LEDS_TRIGGER_DISK Kconfig entry ==='
grep -n -B2 -A8 'config LEDS_TRIGGER_DISK' /vol/kernel-src/drivers/leds/trigger/Kconfig
echo
echo '=== what depends on it ==='
sed -n '/config LEDS_TRIGGER_DISK/,/^config /p' /vol/kernel-src/drivers/leds/trigger/Kconfig | head -14
