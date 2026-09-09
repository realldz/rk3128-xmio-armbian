#!/usr/bin/env bash
set -uo pipefail
U=/workspace/output/planb-stock-uboot/uboot-stock.img
echo "=== 1. IDB/SN/chip info strings in stock uboot ==="
strings -t x "$U" | grep -i -E 'idb|chip_info|chipinfo|serial|SN[:= ]|efuse' | head -20
echo "=== 2. mac/env set strings ==="
strings -t x "$U" | grep -i -E 'setenv|ethaddr|ethernet|mac addr' | head -15
echo "=== 3. what does stock uboot do with usbethaddr (context lines) ==="
python3 - "$U" <<'EOF'
import sys
d=open(sys.argv[1],'rb').read()
for pat in [b'usbethaddr', b'ethernet%d', b'eth%daddr', b'local-mac-address']:
    i=d.find(pat)
    print(f'{pat!r} @ {hex(i)}', d[max(0,i-48):i+48] if i>0 else '')
EOF
echo "=== 4. idbloader.img (A26) — is it a packaged miniloader? ==="
A='/workspace/A26-release-20260430/A26-release-20260430/idbloader.img'
ls -la "$A" 2>/dev/null && python3 -c "
d=open('$A','rb').read(); print('size',hex(len(d)))
for off in range(0,0x400,512):
    row=d[off:off+512]; nz=sum(1 for b in row if b)
    print(f'sec{off//512} nonzero={nz}', ''.join(chr(b) if 32<=b<127 else '.' for b in row[:48]))
"
