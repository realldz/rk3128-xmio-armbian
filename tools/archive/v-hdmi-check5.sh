#!/bin/sh
# hdmi-report v1 — one-shot HDMI diagnostics for RK3128 XMIO (Armbian 6.6.89-rk3128)
# Run on-box:  sh /usr/local/sbin/hdmi-report > /tmp/hdmi-report.txt 2>&1
# Then: cat /tmp/hdmi-report.txt   (paste the whole file back)

B="=============================="

echo "$B"
echo "0. meta"
echo "$B"
uname -a
uptime
echo "note: fill in - was the HDMI cable plugged BEFORE power-on? (yes/no)"
echo "note: which TV port was used, and does the SAME cable+port work with other devices?"

echo
echo "$B"
echo "1. system state (did userspace fully come up?)"
echo "$B"
systemctl is-system-running 2>&1
systemd-analyze 2>/dev/null
systemctl --failed --no-pager 2>/dev/null | head -15
journalctl -b -p err --no-pager 2>/dev/null | tail -15

echo
echo "$B"
echo "2. DRM sysfs overview"
echo "$B"
ls -la /sys/class/drm/ 2>/dev/null
for f in /sys/class/drm/card0-*/status; do echo "$f: $(cat "$f" 2>/dev/null)"; done

echo
echo "$B"
echo "3. connector card0-HDMI-A-1 detail"
echo "$B"
C=/sys/class/drm/card0-HDMI-A-1
if [ -d "$C" ]; then
  for f in status enabled dpms modes; do
    if [ -f "$C/$f" ]; then
      echo "--- $f ---"
      cat "$C/$f"
      echo
    fi
  done
  if [ -s "$C/edid" ]; then
    echo "--- edid: $(wc -c < "$C/edid") bytes, hexdump ---"
    od -A x -t x1z -v "$C/edid" | head -10
  else
    echo "--- edid: EMPTY or missing ---"
  fi
else
  echo "connector card0-HDMI-A-1 DOES NOT EXIST"
fi

echo
echo "$B"
echo "4. HPD interrupt counter (two samples 3s apart, idle)"
echo "$B"
grep -i hdmi /proc/interrupts
sleep 3
grep -i hdmi /proc/interrupts

echo
echo "$B"
echo "5. kernel log: DRM/HDMI/VOP/fbcon/lima + boot health"
echo "$B"
dmesg | grep -iE 'drm|hdmi|vop|inno|lima|fbcon|frame.?buffer|console \[tty' | head -60
echo
echo "--- rknand / vendor storage ---"
dmesg | grep -iE 'rknand|vendor storage' | head -10
echo
echo "--- ext4 rootfs mount state ---"
dmesg | grep -E 'ext4|VFS' | tail -10

echo
echo "$B"
echo "6. framebuffer / console"
echo "$B"
cat /proc/fb 2>/dev/null
for fb in /sys/class/graphics/fb0; do
  if [ -d "$fb" ]; then
    echo "fb0: virtual_size=$(cat "$fb/virtual_size" 2>/dev/null) mode=$(cat "$fb/mode" 2>/dev/null) blank=$(cat "$fb/blank" 2>/dev/null)"
  fi
done
echo "vtcon0 bind: $(cat /sys/class/vtconsole/vtcon0/bind 2>/dev/null)"
echo "vtcon1 bind: $(cat /sys/class/vtconsole/vtcon1/bind 2>/dev/null)"

echo
echo "$B"
echo "7. userspace display stack"
echo "$B"
ls -la /dev/dri 2>/dev/null
pgrep -a Xorg 2>/dev/null || echo "no Xorg process"
for dm in lightdm gdm sddm; do echo "$dm: $(systemctl is-active $dm 2>/dev/null)"; done

echo
echo "$B"
echo "8. self checksum (verify paste integrity)"
echo "$B"
md5sum /usr/local/sbin/hdmi-report 2>/dev/null

echo "END of report"
