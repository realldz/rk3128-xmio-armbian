#!/usr/bin/env python3
"""Pack files into a Rockchip resource.img (RSCE format), matching
tools/rockchip/resource_tool.c in the vendor U-Boot tree:
  block 0: resource_ptn_header  (magic RSCE, hdr_size=1 block, tbl_offset=1,
           tbl_entry_size=1 block, entry_num at offset 12)
  blocks 1..N: index_tbl_entry (tag ENTR, path[220], hash[32], hash_size u32,
           content_offset u32 in blocks, content_size u32 in bytes)
  then contents, each starting at a 512B block boundary.
Usage: pack_resource.py out.img path=path1,name=entry1 [path=...,name=...]
"""
import sys, struct

BLOCK = 512

def pack(out, items):
    # items: list of (entry_name, file_path)
    # C struct: magic[4] u16 u16 u8 u8 u8 pad u32 -> '<4sHHBBHI' with H@10
    # absorbing (tbl_entry_size + zero pad byte); block-align everything.
    header = struct.pack('<4sHHBBHI', b'RSCE', 0, 0, 1, 1, 1, len(items))
    header = header.ljust(BLOCK, b'\0')
    entries = b''
    content_off = 1 + len(items)          # in blocks
    blobs = b''
    for name, path in items:
        data = open(path, 'rb').read()
        entry = struct.pack('<4s220s32sIII',
                            b'ENTR', name.encode()[:219], b'\0'*32, 0,
                            content_off + len(blobs)//BLOCK, len(data))
        entries += entry.ljust(BLOCK, b'\0')
        pad = (-len(data)) % BLOCK
        blobs += data + b'\0'*pad
    img = header + entries + blobs
    open(out, 'wb').write(img)
    print(f'packed {out}: {len(items)} entries, {len(img)} bytes')

def unpack(img_path):
    data = open(img_path, 'rb').read()
    magic, rv, iv, hs, to, tes, num = struct.unpack_from('<4sHHBBHI', data, 0)
    assert magic == b'RSCE', magic
    print(f'unpack {img_path}: entries={num} hdr_size={hs} tbl_off={to} esz={tes}')
    off = hs*BLOCK
    for i in range(num):
        tag, path, hash_, hsz, coff, csz = struct.unpack_from('<4s220s32sIII', data, off + i*tes*BLOCK)
        assert tag == b'ENTR', tag
        name = path.split(b'\0')[0].decode()
        print(f'  entry {i}: {name} off={coff} blocks size={csz}')
        out = f'{img_path}.{i}.{name.replace("/", "_")}'
        open(out, 'wb').write(data[coff*BLOCK: coff*BLOCK + csz])
        print(f'    -> {out}')

if __name__ == '__main__':
    if sys.argv[1] == '--unpack':
        unpack(sys.argv[2])
    else:
        out = sys.argv[1]
        items = []
        for arg in sys.argv[2:]:
            kv = dict(p.split('=', 1) for p in arg.split(','))
            items.append((kv['name'], kv['path']))
        pack(out, items)
