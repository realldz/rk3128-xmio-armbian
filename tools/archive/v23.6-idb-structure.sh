#!/usr/bin/env bash
set -uo pipefail
M='/workspace/output/planb-stock-uboot/rk3128MiniLoaderAll(L)_V2.25_ink.bin'
echo "=== 1. miniloader first 8KB, hex+ascii (find IDB header + MAC slot) ==="
python3 - "$M" <<'EOF'
import sys
d = open(sys.argv[1],'rb').read()
print('size:', len(d), hex(len(d)))
for off in range(0, 8192, 512):
    row = d[off:off+512]
    asc = ''.join(chr(b) if 32 <= b < 127 else '.' for b in row)
    nz = sum(1 for b in row if b)
    print(f'sec{off//512:3d} @0x{off:04x} nonzero={nz:3d}  {asc[:64]}')
EOF
echo "=== 2. 'BOOT LOADER' style sector headers ==="
python3 -c "
d=open('$M','rb').read()
for pat in [b'BOOT', b'LOADER', b'BOOT LOADER!', b'RK', b'SN', b'MAC']:
    i=0; hits=[]
    while True:
        i=d.find(pat,i)
        if i<0 or len(hits)>=6: break
        hits.append(hex(i)); i+=1
    print(pat, hits)
"
echo "=== 3. blob IDB symbols: exported? writable? ==="
nm /vol/kernel-build/vmlinux | grep -E 'rknand_get_idb_data|Flash(Read|Write)Idb|g_idb_buffer'
grep -c 'ksymtab.*rknand_get_idb_data' /vol/kernel-build/System.map 2>/dev/null || true
grep -E 'rknand_get_idb_data|FlashReadIdbData|FlashWriteIdb' /vol/kernel-build/System.map | head -6
echo "=== 4. 3.10-style: does A26 blob store idb raw in g_idb_buffer? who reads ==="
grep -rn 'g_idb_buffer\|rknand_get_idb_data' /vol/kernel-src/drivers/rk_nand/ | head -6
