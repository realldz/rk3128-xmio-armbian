#!/usr/bin/env bash
set -uo pipefail
U=/workspace/output/planb-stock-uboot/uboot-stock.img
echo "=== 1. env-like strings in uboot (default env blob) ==="
strings -t x "$U" | grep -E 'baudrate=|bootcmd=|bootdelay=|bootargs=|ethaddr=|ipaddr=|console=' | head -15
echo "=== 2. hexdump around 'baudrate=' ==="
OFF=$(python3 -c "d=open('$U','rb').read(); print(d.find(b'baudrate='))")
echo "offset: $OFF (0x$(printf %x $OFF))"
python3 - "$U" <<'EOF'
import sys
d = open(sys.argv[1],'rb').read()
o = d.find(b'baudrate=')
# dump the env string table around it
start = max(0, o-0x200); end = min(len(d), o+0x600)
seg = d[start:end]
# print all NUL-separated strings with offsets
cur = b''
cur_off = start
for i,b in enumerate(seg):
    if b == 0:
        if len(cur) > 2:
            print(f'0x{cur_off:06x} ({len(cur):3d}B) {cur.decode(errors="replace")}')
        cur = b''; cur_off = start+i+1
    else:
        if not cur: cur_off = start+i
        cur += bytes([b])
EOF
echo "=== 3. is there an 'ethaddr=' in default env already? ==="
python3 -c "d=open('$U','rb').read(); print('ethaddr= count:', d.count(b'ethaddr=')); print('usbethaddr count:', d.count(b'usbethaddr'))"
echo "=== 4. total uboot size ==="
ls -la "$U"
