#!/usr/bin/env bash
# v24.3b2-als.sh — doc dung 2 script save/restore cua armbian-led-state
set -uo pipefail
IMG=/workspace/output/armbian_rootfs_v23_xmio.img

echo "=== 1. /usr/lib/armbian co gi ==="
debugfs -R "ls -l /usr/lib/armbian" "$IMG" 2>/dev/null

echo
echo "=== 2. restore.sh ==="
debugfs -R "cat /usr/lib/armbian/armbian-led-state-restore.sh" "$IMG" 2>/dev/null

echo
echo "=== 3. save.sh ==="
debugfs -R "cat /usr/lib/armbian/armbian-led-state-save.sh" "$IMG" 2>/dev/null

echo
echo "=== 4. thu muc state (conf) ==="
debugfs -R "ls -la /var/lib/armbian-led-state" "$IMG" 2>/dev/null || echo "(chua co - se tao khi save lan dau)"