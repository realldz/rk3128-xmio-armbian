#!/bin/bash
# xmio-collect — thu thập thông tin chẩn đoán cho XMIO RK3128 Armbian build.
# Chạy trên box: sudo xmio-collect  → tạo /tmp/xmio-report.txt, gửi file này về.
R=/tmp/xmio-report.txt
{
echo "===== XMIO RK3128 diagnostic report $(date) ====="
echo "--- uname / uptime"; uname -a; uptime
echo "--- boot source & cmdline"; cat /proc/cmdline
echo "--- armbianEnv.txt"; cat /boot/armbianEnv.txt 2>/dev/null
echo "--- DTB files"; ls -la /boot/dtb/ 2>/dev/null
echo "--- CPU freqs"; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
echo "--- dmesg (full)"; dmesg 2>/dev/null
echo "--- USB: lsusb"; lsusb 2>/dev/null
echo "--- USB: devices tree"; ls -R /sys/bus/usb/devices/ 2>/dev/null | head -60
echo "--- GPIO3 lines (VBUS hog)"; gpioinfo gpiochip3 2>/dev/null || cat /sys/kernel/debug/gpio 2>/dev/null | grep -A30 gpio3
echo "--- Network"; ip addr 2>/dev/null; ethtool eth0 2>/dev/null | head -20
echo "--- WiFi"; nmcli dev status 2>/dev/null; lsmod 2>/dev/null | grep -E 'esp8089|8189|ssv'
echo "--- HDMI / DRM"; for f in /sys/class/drm/card*-*; do echo "$f: $(cat $f/status 2>/dev/null) $(cat $f/enabled 2>/dev/null)"; done 2>/dev/null; ls /sys/class/drm/ 2>/dev/null
echo "--- Storage"; lsblk 2>/dev/null; cat /proc/mtd 2>/dev/null
echo "--- Memory"; free -m
echo "--- Loaded modules"; lsmod
echo "===== end report ====="
} > "$R" 2>&1
echo "Report saved: $R ($(wc -l < "$R") lines)"
echo "Gửi file này về trợ lý (nội dung hoặc paste toàn bộ)."
