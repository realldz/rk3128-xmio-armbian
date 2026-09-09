#!/usr/bin/env bash
exec > /workspace/work/v19-analysis6.log 2>&1
echo '=== all LED triggers in tree ==='
ls /vol/kernel-src/drivers/leds/trigger/
echo
echo '=== blkdev trigger present? ==='
grep -n -A8 'config LEDS_TRIGGER_BLKDEV' /vol/kernel-src/drivers/leds/trigger/Kconfig || echo 'NO LEDS_TRIGGER_BLKDEV'
ls /vol/kernel-src/drivers/leds/trigger/ledtrig-blkdev* 2>/dev/null || echo 'no ledtrig-blkdev source'
