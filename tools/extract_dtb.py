#!/usr/bin/env python3
"""Extract DTBs from a Rockchip resource.img / any blob; parse Android boot.img."""
import struct, sys, os

DTB_MAGIC = b'\xd0\x0d\xfe\xed'

def extract_dtbs(data, outdir, prefix='dtb'):
    found = []
    off = 0
    while True:
        i = data.find(DTB_MAGIC, off)
        if i < 0:
            break
        off = i + 4
        if i % 4 != 0:
            continue
        if i + 40 > len(data):
            continue
        totalsize = struct.unpack('>I', data[i+4:i+8])[0]
        if not (0x400 <= totalsize <= 0x400000) or i + totalsize > len(data):
            continue
        # sanity: version fields
        last_comp = struct.unpack('>I', data[i+20:i+24])[0]
        boot_cpuid = struct.unpack('>I', data[i+16:i+20])[0]
        if last_comp > 0x20 or boot_cpuid > 0x1000:
            continue
        found.append((i, totalsize))
        off = i + totalsize
    saved = []
    for idx, (i, sz) in enumerate(found):
        name = f'{prefix}_{i:08x}.dtb'
        with open(os.path.join(outdir, name), 'wb') as f:
            f.write(data[i:i+sz])
        saved.append(name)
    return saved

def parse_bootimg(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data[:8] != b'ANDROID!':
        print('not an ANDROID boot image')
        return
    (magic, ksize, kaddr, rsize, raddr, ssize, saddr,
     tags, page, dt_size, _unused, name) = struct.unpack('<8sIIIIIIIIII12s', data[:60])
    print(f'boot.img: kernel={ksize} ramdisk={rsize} second={ssize} dt={dt_size} page={page} name={name}')
    hdr = page
    def roundup(x): return (x + page - 1) // page * page
    koff = hdr
    roff = koff + roundup(ksize)
    soff = roff + roundup(rsize)
    doff = soff + roundup(ssize)
    out = {}
    out['kernel'] = data[koff:koff+ksize]
    if rsize: out['ramdisk.gz'] = data[roff:roff+rsize]
    if ssize: out['second'] = data[soff:soff+ssize]
    if dt_size: out['dt'] = data[doff:doff+dt_size]
    return out

if __name__ == '__main__':
    cmd = sys.argv[1]
    outdir = sys.argv[3] if len(sys.argv) > 3 else '.'
    os.makedirs(outdir, exist_ok=True)
    with open(sys.argv[2], 'rb') as f:
        data = f.read()
    if cmd == 'dtbs':
        saved = extract_dtbs(data, outdir)
        print(f'{len(saved)} DTB(s) extracted:')
        for s in saved:
            print(' ', s)
    elif cmd == 'bootimg':
        out = parse_bootimg(sys.argv[2])
        if out:
            for name, blob in out.items():
                p = os.path.join(outdir, name)
                with open(p, 'wb') as f:
                    f.write(blob)
                print(f'wrote {p} ({len(blob)} bytes)')
                extract_dtbs(blob, outdir, prefix=os.path.splitext(name)[0] + '-dtb')
    elif cmd == 'find':
        saved = extract_dtbs(data, outdir)
        print(f'{len(saved)} DTB(s) found anywhere in file:')
        for s in saved:
            print(' ', s)
