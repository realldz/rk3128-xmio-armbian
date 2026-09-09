#!/usr/bin/env python3
"""Parse RKAF (RKAF) header — reverse-engineered from stock update.img AFP."""
import struct, sys

def parse(path, dump=False):
    data = open(path, 'rb').read(8192)
    print("magic:", data[0:4])
    print("hdr-ver/file-ver @4:", data[4:8].hex())
    print("chip @0x08 (40B):", data[8:48].rstrip(b'\x00').decode(errors='replace'))
    print("id   @0x30 (32B):", data[48:80].rstrip(b'\x00').decode(errors='replace'))
    print("mfg  @0x50 (32B):", data[80:112].rstrip(b'\x00').decode(errors='replace'))
    print("unk  @0x70 (4B):", data[112:116].hex())
    n = struct.unpack('<I', data[116:120])[0]
    print("itemCount @0x74:", n)
    items = []
    off = 120
    for i in range(n):
        name = data[off:off+50].split(b'\x00')[0].decode(errors='replace')
        path_s = data[off+50:off+100].split(b'\x00')[0].decode(errors='replace')
        f1 = struct.unpack('<I', data[off+100:off+104])[0]
        f2 = struct.unpack('<I', data[off+104:off+108])[0]
        f3 = struct.unpack('<I', data[off+108:off+112])[0]
        f4 = struct.unpack('<I', data[off+112:off+116])[0]
        f5 = struct.unpack('<I', data[off+116:off+120])[0]
        print(f"[{i:2d}] name={name!r:22} path={path_s!r:40} pos={f1:#x} fmt={f2:#x} idx={f3} dataOff={f4:#x} dataSize={f5:#x}")
        items.append((name, path_s, f1, f2, f3, f4, f5))
        off += 120
    import os
    sz = os.path.getsize(path)
    print("AFP total size:", sz, hex(sz))
    if dump:
        print("\n--- verify each item's data offset/size against file ---")
        ok = True
        for (name, path_s, f1, f2, f3, f4, f5) in items:
            if f5 == 0 or f5 == 0xFFFFFFFF:
                print(f"  {name}: no inline data (f5={f5:#x})")
                continue
            expect_end = f4 + f5
            print(f"  {name}: data @{f4:#x}..{expect_end:#x} (size {f5})")
        return items
    return items

if __name__ == '__main__':
    parse(sys.argv[1], dump=('-d' in sys.argv))
