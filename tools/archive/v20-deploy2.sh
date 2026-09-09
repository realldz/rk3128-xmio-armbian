#!/usr/bin/env bash
set -euo pipefail
cd /workspace/output/planb-stock-uboot/onbox
# 1. copy binary + gz to a Windows-visible path for scp/http
cp /workspace/tools/xmio-led-arm.gz ./xmio-led-arm.gz
cp /workspace/tools/xmio-led-arm ./xmio-led-arm
echo '--- files for network transfer ---'
md5sum xmio-led-arm.gz xmio-led-arm
ls -la xmio-led-arm.gz xmio-led-arm
# 2. build 4-chunk UART fallback with cumulative md5s
rm -f chunk*.b64
split -l 17 xmio-led-c.b64 chunk
i=1
acc=/tmp/acc.b64; : > $acc
for f in chunk*.b64; do
  cat "$f" >> $acc
  m=$(md5sum $acc | cut -d' ' -f1)
  lines=$(wc -l < $acc)
  echo "CHUNK $i: file=$f lines_total=$lines cumulative_md5=$m"
  i=$((i+1))
done
echo '--- full b64 md5 (for reference) ---'
md5sum xmio-led-c.b64
