#!/usr/bin/env python3
# v19.2-dts.py — yellow LED is wired active-low. Flip GPIO flags 0x00 -> 0x01
# on the io-led only. Status-led (dual rg) stays active-high.
import sys

SRC, DST = sys.argv[1], sys.argv[2]
s = open(SRC).read()
old = '''\t\tio-led {
\t\t\tlabel = "xmio:yellow:io";
\t\t\tgpios = <0x71 9 0x00>;'''

# the source uses the phandle var; find generically
import re
m = re.search(r'(io-led \{\n\t*label = "xmio:yellow:io";\n\t*gpios = <0x[0-9a-fA-F]+ 9 )0x00(>;)', s)
if not m:
    # maybe already flipped (idempotent)
    if re.search(r'io-led \{\n\t*label = "xmio:yellow:io";\n\t*gpios = <0x[0-9a-fA-F]+ 9 0x01>;', s):
        print('V19LED2: already active-low, copy-through')
        open(DST, 'w').write(s)
        sys.exit(0)
    raise SystemExit('yellow gpios line not found')
s = s[:m.start()] + m.group(1) + '0x01' + m.group(2) + s[m.end():]
open(DST, 'w').write(s)
print('V19LED2_OK: yellow now GPIO_ACTIVE_LOW')
