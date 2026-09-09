#!/usr/bin/env python3
# v23.2-dts.py — set the factory label MAC (B8:3D:4E:84:3D:A3) as
# local-mac-address on the gmac node. Authoritative factory MAC from
# the box label; efuse holds no MAC (verified by dump).
import sys, re
src, dst = sys.argv[1], sys.argv[2]
MAC = '[B8 3D 4E 84 3D A3]'
d = open(src).read()
if 'local-mac-address' in d:
    # already set by a previous run of this tool — verify value
    assert MAC in d, 'different MAC already present'
    print('already present (idempotent)')
else:
    m = re.search(r'(ethernet@2008c000 \{\n)', d)
    assert m, 'gmac node not found'
    d = d.replace(m.group(1), m.group(1) + '\t\tlocal-mac-address = ' + MAC + ';\n', 1)
    print('label MAC inserted')
open(dst, 'w').write(d)
