#!/usr/bin/env bash
set -euo pipefail
cd /workspace/tools
gzip -9 -c xmio-led-arm > xmio-led-arm.gz
cd /workspace/output/planb-stock-uboot/onbox
cp -f /workspace/tools/xmio-led-arm.gz ./xmio-led-arm.gz
cp -f /workspace/tools/xmio-led-arm ./xmio-led-arm-v20.1
base64 -w 76 xmio-led-arm.gz > xmio-led-c.b64
rm -f chunk*
split -l 17 xmio-led-c.b64 chunk
i=1; acc=/tmp/acc.b64; : > $acc
for f in chunkaa chunkab chunkac chunkad; do
  cat "$f" >> $acc
  m=$(md5sum $acc | cut -d' ' -f1)
  echo "CHUNK $i: cum_md5=$m"
  i=$((i+1))
done
echo '--- deliverables ---'
md5sum xmio-led-arm.gz xmio-led-arm-v20.1 xmio-led-c.b64
ls -la xmio-led-arm.gz xmio-led-arm-v20.1 xmio-led-c.b64 chunk*
