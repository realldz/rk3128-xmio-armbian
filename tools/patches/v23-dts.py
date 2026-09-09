#!/usr/bin/env python3
# v23-dts.py — strip the hardcoded local-mac-address from the ethernet node
# so the stmmac probe falls through to rk_get_eth_addr -> vendor storage.
import sys
src, dst = sys.argv[1], sys.argv[2]
d = open(src).read()
line = '\t\tlocal-mac-address = [02 31 28 16 01 28];\n'
if line in d:
    d = d.replace(line, '', 1)
    print('local-mac-address removed')
else:
    assert 'local-mac-address' not in d, 'unexpected other mac-address entries'
    print('already absent (idempotent)')
open(dst, 'w').write(d)
