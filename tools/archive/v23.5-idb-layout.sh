#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. /vol top-level (any SDK dirs?) ==="
ls /vol/ 2>/dev/null
echo "=== 2. any rk SDK / android source / tools in container ==="
for d in /vol /opt /srv /usr/local /root; do
  find $d -maxdepth 3 \( -iname '*rk3128*' -o -iname '*rk30*sdk*' -o -iname '*android*tool*' -o -iname 'afptool*' -o -iname 'mkImage*' -o -iname 'rkcrc*' -o -iname '*IDB*' \) 2>/dev/null | head -8
done
echo "=== 3. workspace: parameter/afptool artifacts ==="
ls /workspace/output/planb-stock-uboot/ | head -30
echo "=== 4. parameter.txt (partition defs incl IDB?) ==="
cat /workspace/output/planb-stock-uboot/parameter.txt 2>/dev/null | head -20
echo "=== 5. miniloader: dump sections + size ==="
M='/workspace/output/planb-stock-uboot/rk3128MiniLoaderAll(L)_V2.25_ink.bin'
ls -la "$M"
strings -t x "$M" | grep -i -E 'idblock|idb|loader|version' | head -20
