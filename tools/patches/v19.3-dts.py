#!/usr/bin/env python3
# v19.3-dts.py — remove heartbeat default-trigger from status-led.
# Rationale: trigger binding at boot is racy (sometimes binds -> dual LED
# looks green because pin-low phase dominates; service brightness writes
# are swallowed while a trigger is active). Pre-systemd LED = solid red
# (default-state=on) deterministic; xmio-led service owns everything after.
import sys

SRC, DST = sys.argv[1], sys.argv[2]
s = open(SRC).read()

line = '\t\t\tlinux,default-trigger = "heartbeat";\n'
if line in s:
    s = s.replace(line, '', 1)
    print('V19DTB3_OK: heartbeat trigger removed')
elif 'default-trigger' not in s:
    print('V19DTB3: already absent, copy-through')
else:
    raise SystemExit('unexpected default-trigger content')
open(DST, 'w').write(s)
