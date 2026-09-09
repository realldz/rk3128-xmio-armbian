#!/usr/bin/env bash
exec > /workspace/work/v19-analysis1.log 2>&1
echo '=== "led" in stock dts ==='
grep -in 'led\|gpio-leds' /workspace/work/stock-dtbs/rk312x-stock.dts | head -15
echo
echo '=== "led" in planb v17 dts ==='
grep -in 'led\|gpio-leds' /workspace/work/xmio-planb-v17.dts | head -15
echo
echo '=== kernel LED configs current ==='
grep -E 'CONFIG_NEW_LEDS|CONFIG_LEDS_CLASS|CONFIG_LEDS_GPIO|CONFIG_LEDS_TRIGGERS|CONFIG_LEDS_TRIGGER' /vol/kernel-build/.config || echo '(none)'
echo
echo '=== gpio0/gpio1 controllers in planb dts ==='
grep -n 'gpio@2007a000\|gpio@2007c000\|gpio@20080000\|gpio@20084000\|gpio@20088000' /workspace/work/xmio-planb-v17.dts | head -8
