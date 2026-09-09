#!/bin/bash
# v-hdmi-check4.sh — inspect shipped DTB nodes
DTB=/workspace/output/planb-stock-uboot/resource.img.0.rk-kernel.dtb
dtc -I dtb -O dts -o /tmp/planb-current.dts "$DTB" 2>/dev/null
echo "decompile: $?"
wc -l /tmp/planb-current.dts

echo
echo '=== hdmi node ==='
grep -n -A25 'hdmi@20034000' /tmp/planb-current.dts | head -40

echo
echo '=== vop / vopl status ==='
grep -n -B1 -A6 'vop@\|vopl@' /tmp/planb-current.dts | head -30

echo
echo '=== lcdc (stock-style) status ==='
grep -n -A3 'lcdc@' /tmp/planb-current.dts | head -12

echo
echo '=== route/display-subgraph ==='
grep -n 'route_hdmi\|connect = \|ports {' /tmp/planb-current.dts | head -20

echo
echo '=== gmac mac ==='
grep -n -B3 -A1 'local-mac-address' /tmp/planb-current.dts | head -12

echo
echo '=== leds ==='
grep -n -A8 'xmio-leds' /tmp/planb-current.dts | head -30

echo
echo '=== compare with v23.2 source dts (hdmi section) ==='
grep -n -A20 'hdmi@20034000' /workspace/work/xmio-planb-v23.2.dts | head -30
