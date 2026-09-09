#!/usr/bin/env bash
# v24.2-verify.sh — DTS thật sự chứa gì? node cpuinfo có cell-names không?
set -uo pipefail
W=/workspace/work/xmio-planb-v23.dts
echo "=== 1. mtime + so lan xuat hien ==="
ls -la "$W"
grep -c 'rockchip,cpuinfo' "$W" || echo "0 lan"
echo
echo "=== 2. toan bo node cpuinfo trong DTS ==="
grep -n -A5 'cpuinfo' "$W" | head -40
echo
echo "=== 3. decompile resource.img hien tai (file da SHIP) ==="
python3 - <<'EOF'
import struct, zlib, sys
d = open('/workspace/output/planb-stock-uboot/resource.img','rb').read()
print('resource size:', len(d))
# resource: header "RSCE"... tim rk-kernel.dtb blob (dtb bat dau bang d0 0d fe ed)
import re
i = d.find(b'\xd0\x0d\xfe\xed')
if i < 0:
    print('no dtb blob!'); sys.exit(1)
# luu dtb tu header den het (dung boot.img second offset trick: dtb co totalsize)
tot = struct.unpack_from('>I', d, i+4)[0]
open('/tmp/ship.dtb','wb').write(d[i:i+tot])
print('dtb bytes:', tot)
EOF
dtc -I dtb -O dts /tmp/ship.dtb 2>/dev/null > /tmp/ship.dts
grep -n -A4 'cpuinfo' /tmp/ship.dts | head -12
echo
echo "=== 4. git status file (neu la repo) ==="
cd /workspace && git status --short work/xmio-planb-v23.dts 2>/dev/null | head -3 || echo "(khong phai git hoac chua track)"