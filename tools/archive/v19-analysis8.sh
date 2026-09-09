#!/usr/bin/env bash
exec > /workspace/work/v19-analysis8.log 2>&1
SRC=/vol/kernel-src
echo '=== led-class.c: default_trigger handling at LED registration ==='
grep -n 'default_trigger' $SRC/drivers/leds/led-class.c | head -10
echo
echo '=== led-trigger.c: does led_trigger_register retro-bind to LEDs with matching default_trigger? ==='
grep -n -A20 'int led_trigger_register(' $SRC/drivers/leds/led-trigger.c | head -40
echo
echo '=== led_trigger_set_default ==='
grep -n -B2 -A15 'static void led_trigger_set_default' $SRC/drivers/leds/led-trigger.c
echo
echo '=== leds-gpio: does probe read linux,default-trigger and set cdev field? ==='
grep -n 'default_trigger\|default-state' $SRC/drivers/leds/leds-gpio.c | head -10
echo
echo '=== does led_trigger_set(NULL) force brightness off? ==='
grep -n -A25 'void led_trigger_set(' $SRC/drivers/leds/led-trigger.c | head -35
echo
echo '=== initcall order: leds-gpio vs ledtrig-heartbeat (Makefile link order) ==='
grep -n 'leds-gpio' $SRC/drivers/leds/Makefile
grep -n 'heartbeat' $SRC/drivers/leds/trigger/Makefile
grep -n 'obj-y\s*+=\s*trigger/' $SRC/drivers/leds/Makefile
