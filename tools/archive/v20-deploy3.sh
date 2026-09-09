#!/usr/bin/env bash
set -euo pipefail
cd /workspace/output/planb-stock-uboot/onbox
rm -f chunk*
split -l 17 xmio-led-c.b64 chunk
i=1
acc=/tmp/acc.b64; : > $acc
for f in chunkaa chunkab chunkac chunkad; do
  cat "$f" >> $acc
  m=$(md5sum $acc | cut -d' ' -f1)
  lines=$(wc -l < $acc)
  first=$(head -1 "$f" | cut -c1-24)
  last=$(tail -1 "$f" | cut -c1-24)
  echo "CHUNK $i ($f): lines_total=$lines cumulative_md5=$m first24=$first last24=$last"
  i=$((i+1))
done
