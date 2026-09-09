#!/bin/bash
# v-hdmi-dtb-resmem.sh — compare reserved-memory nodes baseline vs current DTB
echo '=== BASELINE (v17 era, HDMI-OK) reserved-memory ==='
awk '/reserved-memory \{/,/^\t};/' /tmp/res-base.dts | head -50

echo
echo '=== CURRENT (b12893c9, v23.2 chain) reserved-memory ==='
awk '/reserved-memory \{/,/^\t};/' /tmp/planb-current.dts | head -50

echo
echo '=== grep drm-logo in both ==='
grep -n -A6 'drm-logo' /tmp/res-base.dts | head -12
echo ---
grep -n -A6 'drm-logo' /tmp/planb-current.dts | head -12
