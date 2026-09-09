#!/usr/bin/env bash
# v20-deploy.sh — build UART deploy package for xmio-led C daemon
set -euo pipefail
cd /workspace/tools
gzip -9 -c xmio-led-arm > /tmp/xmio-led-arm.gz
base64 -w 76 /tmp/xmio-led-arm.gz > /workspace/output/planb-stock-uboot/onbox/xmio-led-c.b64
ls -la /workspace/output/planb-stock-uboot/onbox/xmio-led-c.b64
md5sum /tmp/xmio-led-arm.gz
# also embed md5 into the package for on-box verify
echo "expected md5 of decompressed gz: $(md5sum /tmp/xmio-led-arm.gz | cut -d' ' -f1)"
lines=$(wc -l < /workspace/output/planb-stock-uboot/onbox/xmio-led-c.b64)
echo "b64 lines: $lines"
