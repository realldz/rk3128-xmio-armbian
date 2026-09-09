#!/usr/bin/env bash
# v13-initramfs.sh — fine-grained udev instrumentation + hang watchdog.
#   - INITRD-DIAG echoes around EVERY command of scripts/init-top/udev
#   - background watchdog: if no progress in 15 s prints ps/uptime/
#     interrupts/timer_list + stack/wchan of udevadm+udevd; final report
#     at 45 s; kernel alive + watchdog silent => tick died, not UART.
# Repacks output/planb-stock-uboot/initrd.img.gz (original kept as .orig).
set -euo pipefail
OUT=/workspace/output/planb-stock-uboot
W=/tmp/initrd-v13

[ -f "$OUT/initrd.img.gz.orig-A26" ] || cp -f "$OUT/initrd.img.gz" "$OUT/initrd.img.gz.orig-A26"

rm -rf "$W"
mkdir -p "$W"
gzip -dc "$OUT/initrd.img.gz.orig-A26" | cpio -idm -D "$W" 2>/dev/null
echo "unpacked: $(find "$W" -type f | wc -l) files"

# --- 1. udev rule: never blkid rknand* (kept from v12) ---
cat > "$W/lib/udev/rules.d/59-rknand-noblkid.rules" <<'EOF'
# V13DIAG: skip blkid probing on rknand* block devices. The vendor FTL
# read path must only run from the root mount, not from udev workers.
KERNEL=="rknand*", ENV{UDEV_DISABLE_PERSISTENT_STORAGE_BLKID_FLAG}="1"
EOF
echo "OK   59-rknand-noblkid.rules"

# --- 2. rewrite scripts/init-top/udev with full instrumentation ---
cat > "$W/scripts/init-top/udev" <<'EOF'
#!/bin/sh -e

PREREQS=""

prereqs() { echo "$PREREQS"; }

case "$1" in
    prereqs)
    prereqs
    exit 0
    ;;
esac

echo "INITRD-DIAG: udev script enter"

# --- hang watchdog (V13DIAG) -------------------------------------------
(
    sleep 15
    echo "INITRD-DIAG: WATCHDOG 15s - udev script still running"
    cat /proc/uptime
    ps
    echo "---- udevadms ----"
    for p in $(pidof systemd-udevd udevadm 2>/dev/null); do
        echo "== pid $p =="
        cat /proc/$p/stat 2>/dev/null | cut -d' ' -f1-4
        cat /proc/$p/wchan 2>/dev/null; echo
        cat /proc/$p/stack 2>/dev/null || echo "(no stack access)"
    done
    echo "---- interrupts ----"
    cat /proc/interrupts 2>/dev/null | head -40
    echo "---- timer_list (clockevent/clocksource) ----"
    grep -A6 "clockevent\|Clock Event Device\|rk_timer\|clocksource:" /proc/timer_list 2>/dev/null | head -60
    echo "---- clocksource ----"
    cat /sys/devices/system/clocksource/clocksource0/current_clocksource 2>/dev/null
    echo "---- dmesg tail ----"
    dmesg | tail -25
    sleep 30
    echo "INITRD-DIAG: WATCHDOG 45s FINAL - udev script STILL stuck"
    ps
    cat /proc/uptime
    dmesg | tail -25
) &

if [ -w /sys/kernel/uevent_helper ]; then
	echo > /sys/kernel/uevent_helper
fi
echo "INITRD-DIAG: uevent_helper step done"

if [ "${quiet:-n}" = "y" ]; then
	log_level=notice
else
	log_level=info
fi

echo "INITRD-DIAG: starting udevd"
SYSTEMD_LOG_LEVEL=$log_level /lib/systemd/systemd-udevd --daemon --resolve-names=never
echo "INITRD-DIAG: udevd daemon returned"

echo "INITRD-DIAG: trigger subsystems begin"
udevadm trigger --type=subsystems --action=add
echo "INITRD-DIAG: trigger subsystems done"

echo "INITRD-DIAG: trigger devices begin"
udevadm trigger --type=devices --action=add
echo "INITRD-DIAG: udev trigger done"

echo "INITRD-DIAG: settle begin"
udevadm settle || true
echo "INITRD-DIAG: udev settle done"

echo "INITRD-DIAG: udev script exit"
EOF
chmod +x "$W/scripts/init-top/udev"
echo "OK   scripts/init-top/udev rewritten (INITRD-DIAG + watchdog)"

# --- 3. /init markers around mountroot (kept from v12) ---
python3 - <<'EOF'
import io

def patch(path, steps, guard):
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        lines = f.readlines()
    if guard in "".join(lines):
        print("SKIP %s" % path)
        return
    for key, mode, new in steps:
        hits = [i for i, l in enumerate(lines) if key in l]
        if len(hits) != 1:
            raise SystemExit("FATAL: %s: %r hits %d" % (path, key, len(hits)))
        i = hits[0]
        if mode == "after":
            lines[i + 1:i + 1] = new
        elif mode == "before":
            lines[i:i] = new
        else:
            raise SystemExit("FATAL: mode %r" % mode)
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.writelines(lines)
    print("OK   %s (%d markers)" % (path, len(steps)))

patch("/tmp/initrd-v13/init", [
    ("mount_premount", "after", [
        'echo "INITRD-DIAG: mountroot begin"\n',
        'ls -la /dev/rknand* 2>&1 || true\n',
        'echo "INITRD-DIAG: probe read rknand_root (no OK line = FTL read hangs)"\n',
        'dd if=/dev/rknand_root of=/dev/null bs=512 count=1 2>&1 '
        '&& echo "INITRD-DIAG: probe read OK" '
        '|| echo "INITRD-DIAG: probe read FAILED"\n',
    ]),
    ("if read_fstab_entry /usr;", "before", [
        'echo "INITRD-DIAG: mountroot returned"\n',
    ]),
], "INITRD-DIAG")
EOF

# --- 4. repack ---
(cd "$W" && find . -print0 | cpio --null -o -H newc 2>/dev/null) \
  | gzip -9 > "$OUT/initrd.img.gz"
ls -la "$OUT/initrd.img.gz"
file "$OUT/initrd.img.gz"
echo V13_INITRAMFS_OK
