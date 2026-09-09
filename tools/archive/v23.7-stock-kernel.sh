#!/usr/bin/env bash
set -uo pipefail
K=/workspace/work/stock-rkunpack/Image/kernel.img
echo "=== 1. file type / header ==="
ls -la "$K"
xxd "$K" | head -4
echo "=== 2. IDB MAC string present raw? ==="
strings -t x "$K" | grep -i -E 'MAC address|from IDB|ethaddr' | head -8
echo "=== 3. compressed payload? find gzip magic ==="
python3 - "$K" <<'EOF'
import sys
d = open(sys.argv[1],'rb').read()
print('size', len(d))
import re
for m in list(re.finditer(b'\x1f\x8b\x08', d))[:5]:
    print('gzip magic @', hex(m.start()))
# zImage magic
print('zImage magic @', hex(d.find(b'\x18\x28\x6f\x01')))
EOF
