#!/usr/bin/env bash
# planb-v17.1-badnand.sh — create parameter.txt.badnand1: cmdline adds
# bad_nand=1 (NANDC clk 150->50MHz, FTL reserved blocks bumped, retry
# mode forced on). For worn-MLC boxes: wider timing margin, fewer
# marginal-page read retries. Flash 0x0 to test; revert = reflash the
# previous parameter.txt (without bad_nand).
set -euo pipefail
OUT=/workspace/output/planb-stock-uboot

if [ -f "$OUT/parameter.txt.badnand1" ]; then
  echo "already exists"
else
  cp -f "$OUT/parameter.txt" "$OUT/parameter.txt.badnand1"
  python3 - "$OUT/parameter.txt.badnand1" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
assert 'bad_nand=' not in s, 'already patched'
anchor = ' rootfstype=ext4 video='
assert s.count(anchor) == 1, 'anchor missing'
s = s.replace(anchor, ' rootfstype=ext4 bad_nand=1 video=')
open(p, 'w', encoding='utf-8', newline='').write(s)
print('bad_nand=1 patched')
EOF
fi
grep '^CMDLINE:' "$OUT/parameter.txt.badnand1" | head -c 400; echo
md5sum "$OUT/parameter.txt.badnand1"
echo BADNAND1_READY
