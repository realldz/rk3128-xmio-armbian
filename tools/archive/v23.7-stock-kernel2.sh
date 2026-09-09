#!/usr/bin/env bash
set -uo pipefail
K=/workspace/work/stock-rkunpack/Image/kernel.img
python3 - "$K" <<'EOF'
import sys
d = open(sys.argv[1],'rb').read()
print('size', hex(len(d)))
print('first 0x80:')
for i in range(0, 0x80, 16):
    row = d[i:i+16]
    print(f'{i:06x}  ' + ' '.join(f'{b:02x}' for b in row) + '  ' + ''.join(chr(b) if 32<=b<127 else '.' for b in row))
magics = {
    b'\x1f\x8b\x08': 'gzip', b'\x04\x22\x4d\x18': 'lz4-legacy',
    b'\x02\x21\x4c\x18': 'lz4-legacy2', b'\x89LZO': 'lzo',
    b'\xfd7zXZ': 'xz', b'BZh': 'bzip2', b'\x5d\x00\x00': 'lzma',
    b'\x7fELF': 'elf', b'\x1f\x9e\x08': 'gzip-old',
}
for m, name in magics.items():
    hits = []
    i = 0
    while True:
        i = d.find(m, i)
        if i < 0 or len(hits) >= 4: break
        hits.append(hex(i)); i += 1
    if hits: print(name, hits)
# maybe it's an uncompressed vmlinux Image (branch + 'zImage' strings?)
print('has zImage string:', d.find(b'zImage') > 0 and hex(d.find(b'zImage')))
print('has piggy:', d.find(b'piggy') > 0 and hex(d.find(b'piggy')))
EOF
