#!/usr/bin/env bash
# v22-rootfs.sh — RAM-only logging: journald volatile, no rsyslog,
# no sysstat cron, chrony drift to /run. Base: v15j (journal ext4 kept).
# NOTE: debugfs is READ-ONLY by default; all mutations need -w!
set -euo pipefail
OUT=/workspace/output
SRC=$OUT/armbian_rootfs_v15j_xmio.img
DST=$OUT/armbian_rootfs_v22_xmio.img
T=/tmp/v22work
rm -rf $T && mkdir -p $T

echo "=== 1. fresh copy + fsck base ==="
rm -f "$DST"
cp -f "$SRC" "$DST"
e2fsck -fy "$DST" 2>&1 | tail -1

dbg()  { debugfs    -R "$1" "$DST" 2>/dev/null; }
dbgw() { debugfs -w -R "$1" "$DST" 2>&1 | grep -vE '^debugfs:|^$' || true; }

echo "=== 2. journald.conf -> volatile ==="
dbg "dump /etc/systemd/journald.conf $T/journald.conf"
cat >> $T/journald.conf <<'EOF'

# --- v22: RAM-only logging (NAND wear protection) ---
Storage=volatile
RuntimeMaxUse=16M
SystemMaxUse=16M
Compress=no
EOF
dbgw "rm /etc/systemd/journald.conf"
dbgw "write $T/journald.conf /etc/systemd/journald.conf"
dbgw "sif /etc/systemd/journald.conf mode 0100644"
dbgw "sif /etc/systemd/journald.conf uid 0"
dbgw "sif /etc/systemd/journald.conf gid 0"
echo "-- verify conf tail:"
dbg "cat /etc/systemd/journald.conf" | tail -5
dbg "cat /etc/systemd/journald.conf" | grep -q '^Storage=volatile' || { echo FAIL-CONF; exit 1; }

echo "=== 3. remove /var/log/journal ==="
SUBS=$(dbg "ls -p /var/log/journal" | tail -n +3 | awk -F/ '{print $6}' | grep -v '^\.$' | grep -v '^\.\.$' || true)
for s in $SUBS; do
  echo "  subdir: $s"
  for f in $(dbg "ls -p /var/log/journal/$s" | tail -n +3 | awk -F/ '{print $6}' | grep -v '^\.$' | grep -v '^\.\.$'); do
    dbgw "rm /var/log/journal/$s/$f" >/dev/null
    echo "    rm $f"
  done
  dbgw "rmdir /var/log/journal/$s" >/dev/null
  echo "    rmdir $s"
done
dbgw "rmdir /var/log/journal" >/dev/null
if dbg "stat /var/log/journal" | grep -q 'Type:'; then echo FAIL-JOURNAL-DIR; exit 1; fi
echo "  journal dir removed OK"

echo "=== 4. disable rsyslog ==="
dbgw "rm /etc/systemd/system/multi-user.target.wants/rsyslog.service" >/dev/null
if dbg "stat /etc/systemd/system/multi-user.target.wants/rsyslog.service" | grep -q 'Type:'; then echo FAIL-RSYSLOG; exit 1; fi
echo "  rsyslog unlinked OK"

echo "=== 5. remove sysstat crons ==="
dbgw "rm /etc/cron.d/sysstat" >/dev/null
dbgw "rm /etc/cron.daily/sysstat" >/dev/null
if dbg "stat /etc/cron.d/sysstat" | grep -q 'Type:'; then echo FAIL-CRON; exit 1; fi
echo "  sysstat crons removed OK"

echo "=== 6. chrony driftfile -> /run ==="
dbg "dump /etc/chrony/chrony.conf $T/chrony.conf"
sed -i 's|^driftfile /var/lib/chrony/chrony.drift|driftfile /run/chrony/chrony.drift|' $T/chrony.conf
dbgw "rm /etc/chrony/chrony.conf"
dbgw "write $T/chrony.conf /etc/chrony/chrony.conf"
dbgw "sif /etc/chrony/chrony.conf mode 0100644"
dbgw "sif /etc/chrony/chrony.conf uid 0"
dbgw "sif /etc/chrony/chrony.conf gid 0"
printf 'd /run/chrony 0755 _chrony _chrony -\n' > $T/chrony-v22.conf
dbgw "write $T/chrony-v22.conf /usr/lib/tmpfiles.d/chrony-v22.conf"
dbgw "sif /usr/lib/tmpfiles.d/chrony-v22.conf mode 0100644"
dbgw "sif /usr/lib/tmpfiles.d/chrony-v22.conf uid 0"
dbgw "sif /usr/lib/tmpfiles.d/chrony-v22.conf gid 0"
dbg "cat /etc/chrony/chrony.conf" | grep -q '^driftfile /run/chrony' || { echo FAIL-CHRONY; exit 1; }
echo "  chrony drift -> /run OK"

echo "=== 7. final fsck + summary verify ==="
e2fsck -fy "$DST" 2>&1 | tail -1
dbg "ls -p /var/log" | grep -c journal || echo "  /var/log clean of journal"
dbg "ls -p /etc/systemd/system/multi-user.target.wants" | grep -c rsyslog || echo "  no rsyslog in wants"
echo "=== 8. md5 ==="
md5sum "$DST"
ls -la "$DST"
echo V22_ROOTFS_DONE
