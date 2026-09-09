#!/usr/bin/env bash
# planb-v18.1.sh — parameter.txt.native: drop the forced HDMI mode.
# EDID is verified working (preferred 1920x1080@60, HPD IRQ fires, poll
# fallback active) -> full native mode selection. Keep the current
# force-mode parameter as fallback: if the screen stays black after
# boot with .native, reflash parameter.txt @0x0.
set -euo pipefail
OUT=/workspace/output/planb-stock-uboot

if [ -f "$OUT/parameter.txt.native" ]; then
  echo "already exists"
else
  cp -f "$OUT/parameter.txt" "$OUT/parameter.txt.native"
  python3 - "$OUT/parameter.txt.native" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = ' video=HDMI-A-1:1920x1080@60e'
assert s.count(old) == 1, 'video anchor x%d' % s.count(old)
s = s.replace(old, '')
open(p, 'w', encoding='utf-8', newline='').write(s)
print('video= removed (native mode)')
EOF
fi
grep '^CMDLINE:' "$OUT/parameter.txt.native" | head -c 400; echo
md5sum "$OUT/parameter.txt.native"
echo NATIVE_READY
