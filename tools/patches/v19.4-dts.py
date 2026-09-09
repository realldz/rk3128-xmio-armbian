#!/usr/bin/env python3
# v19.4-dts.py — stock mode DTS (input: xmio-planb-v19.3.dts, output: xmio-planb-v19.4.dts)
# status-led: GPIO_ACTIVE_LOW (0x01) so trigger "on" = GREEN, "off" = RED;
#   default-trigger = heartbeat (red-dominant boot flicker, restores spec);
#   default-state = "off" (pre-trigger pin HIGH = RED). io-led untouched:
#   no rknand hook exists in-kernel -> yellow stays dark in stock mode.
import sys, re
src, dst = sys.argv[1], sys.argv[2]
d = open(src).read()

m = re.search(r'(status-led \{.*?\n\t\t\};)', d, re.S)
assert m, 'status-led node not found'
blk = m.group(1)
nb = blk

nb2 = re.sub(r'gpios = <(0x[0-9a-fA-F]+) 8 0x00>;', r'gpios = <\1 8 0x01>;', nb)
if nb2 == nb:
    assert ' 8 0x01>;' in nb, 'flag flip failed'
else:
    nb = nb2

if 'linux,default-trigger' not in nb:
    nb = nb.replace('label = "xmio:red-green:status";\n',
                    'label = "xmio:red-green:status";\n'
                    '\t\t\tlinux,default-trigger = "heartbeat";\n', 1)
assert 'heartbeat' in nb, 'trigger insert failed'

nb = nb.replace('default-state = "on";', 'default-state = "off";')
assert 'default-state = "off";' in nb, 'default-state flip failed'

d = d.replace(blk, nb, 1)
open(dst, 'w').write(d)
print('v19.4-stock dts written (dual ACTIVE_LOW, heartbeat, state off)')
