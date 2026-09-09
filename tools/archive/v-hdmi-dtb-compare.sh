#!/bin/bash
# v-hdmi-dtb-compare.sh — decompile baseline vs current DTB, compare hdmi pinctrl phandles
cd /tmp
rm -f res-base.*
cp /workspace/output/archive/resource-baseline.img res-base.img
python3 /workspace/tools/pack_resource.py --unpack res-base.img
dtc -I dtb -O dts -o res-base.dts res-base.img.0.rk-kernel.dtb 2>/dev/null

echo '=== BASELINE (v17 era, HDMI-OK): hdmi node pinctrl-0 ==='
grep -n -B4 -A2 'pinctrl-0' /tmp/res-base.dts | grep -A2 -B4 'hdmi' | head
grep -n -A22 'hdmi@20034000' /tmp/res-base.dts | grep -E 'pinctrl-0|phandle' | head -5

echo
echo '=== BASELINE: what are phandles 0x67 0x68 0x69? ==='
grep -n -B1 'phandle = <0x67>\|phandle = <0x68>\|phandle = <0x69>' /tmp/res-base.dts | head -10

echo
echo '=== CURRENT (b12893c9): hdmi pinctrl-0 + what 0x67-0x69 point to ==='
grep -n -B1 'phandle = <0x67>\|phandle = <0x68>\|phandle = <0x69>' /tmp/planb-current.dts | head -10

echo
echo '=== CURRENT: hdmi pinctrl node names in file ==='
grep -n 'hdmi_hpd\|hdmi_cec\|hdmii2c\|hdmi-i2c' /tmp/planb-current.dts | head -10
grep -n 'hdmi_hpd\|hdmi_cec\|hdmii2c' /tmp/res-base.dts | head -10
