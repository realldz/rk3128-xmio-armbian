#!/usr/bin/env python3
"""Verify RKFW update.img: md5 trailer + extract BOOT (loader) + embedded AFP."""
import sys, hashlib

def md5_of(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()

src = sys.argv[1]
loader_out = sys.argv[2]
afp_out = sys.argv[3]

data_len = None
import os
total = os.path.getsize(src)

with open(src, 'rb') as f:
    hdr = f.read(0x66)
    assert hdr[0:4] == b'RKFW', hdr[0:4]
    head_len = int.from_bytes(hdr[4:6], 'little')
    # struct _rkfw_header (packed): head_code[4] head_len(u16) version(u32) code(u32)
    # year(u16) month day hour minute second | chip(u32) @0x15
    # loader_offset(u32) @0x19 loader_length(u32) @0x1D
    # image_offset(u32) @0x21 image_length(u32) @0x25
    loader_offset = int.from_bytes(hdr[0x19:0x1d], 'little')
    loader_length = int.from_bytes(hdr[0x1d:0x21], 'little')
    image_offset = int.from_bytes(hdr[0x21:0x25], 'little')
    image_length = int.from_bytes(hdr[0x25:0x29], 'little')
    print(f"head_len={head_len:#x} loader@{loader_offset:#x}+{loader_length:#x} image@{image_offset:#x}+{image_length:#x}")
    print(f"total file size = {total:#x} ({total})")

    # md5 trailer: 32 ASCII chars at end
    f.seek(total - 32)
    trailer = f.read(32).decode()
    print(f"md5 trailer: {trailer}")

    # md5 of everything except trailer
    f.seek(0)
    h = hashlib.md5()
    remaining = total - 32
    while remaining:
        chunk = f.read(min(1 << 20, remaining))
        h.update(chunk)
        remaining -= len(chunk)
    calc = h.hexdigest()
    print(f"md5 calc  : {calc}")
    print("MD5 TRAILER:", "MATCH" if calc == trailer else "MISMATCH!!!")

    # extract BOOT (loader)
    f.seek(loader_offset)
    loader = f.read(loader_length)
    with open(loader_out, 'wb') as o:
        o.write(loader)
    print(f"loader written: {len(loader)} bytes")

    # extract AFP
    f.seek(image_offset)
    remaining = image_length
    with open(afp_out, 'wb') as o:
        while remaining:
            chunk = f.read(min(1 << 20, remaining))
            o.write(chunk)
            remaining -= len(chunk)
    print(f"AFP written: {image_length} bytes")

# verify loader md5 vs stock MiniLoader
stock_loader_md5 = md5_of('/tmp/stock-af-unpacked/rk3128MiniLoaderAll(L)_V2.25_ink.bin')
extracted_loader_md5 = md5_of(loader_out)
print(f"loader md5 extracted={extracted_loader_md5} stock={stock_loader_md5} -> {'MATCH' if extracted_loader_md5 == stock_loader_md5 else 'MISMATCH'}")
