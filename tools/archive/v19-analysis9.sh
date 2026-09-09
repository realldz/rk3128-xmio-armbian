#!/usr/bin/env bash
exec > /workspace/work/v19-analysis9.log 2>&1
IMG=/workspace/output/armbian_rootfs_v15_xmio.img
IMG2=/workspace/output/armbian_rootfs_26.2_xmio.img
echo '=== search led-state units in v15 rootfs (base of box) ==='
debugfs -R "ls -l /usr/lib/systemd/system" "$IMG" 2>/dev/null | grep -iE 'led' || echo 'none in /usr/lib/systemd/system'
debugfs -R "ls -l /etc/systemd/system" "$IMG" 2>/dev/null | grep -iE 'led' || echo 'none in /etc/systemd/system (top)'
debugfs -R "ls -l /etc/systemd/system/multi-user.target.wants" "$IMG" 2>/dev/null | grep -iE 'led' || echo 'none in multi-user.wants'
echo
echo '=== also check 26.2 image (pristine armbian) ==='
debugfs -R "ls -l /usr/lib/systemd/system" "$IMG2" 2>/dev/null | grep -iE 'led' || echo 'none in 26.2 /usr/lib/systemd/system'
echo
echo '=== cat the unit if present (v15) ==='
debugfs -R "cat /usr/lib/systemd/system/armbian-led-state.service" "$IMG" 2>/dev/null || echo 'MISSING v15'
echo
echo '=== cat the unit if present (26.2) ==='
debugfs -R "cat /usr/lib/systemd/system/armbian-led-state.service" "$IMG2" 2>/dev/null || echo 'MISSING 26.2'
echo
echo '=== related scripts search ==='
debugfs -R "ls -l /usr/lib/armbian" "$IMG" 2>/dev/null | grep -iE 'led' || echo 'no led script in /usr/lib/armbian'
debugfs -R "ls -l /usr/sbin" "$IMG" 2>/dev/null | grep -iE 'led' || echo 'no led in /usr/sbin'
