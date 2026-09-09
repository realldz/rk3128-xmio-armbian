#!/usr/bin/env python3
# v19.1-dts.py — add gpio-leds node (dual red/green @ gpio0_8 heartbeat,
# yellow @ gpio1_9) to xmio-planb dts. Idempotent (V19LED marker).
# Handles missing gpio phandles by assigning unused ones.
import re, sys

SRC, DST = sys.argv[1], sys.argv[2]
s = open(SRC).read()

if 'V19LED' in s:
    print('V19LED: already applied, copy-through')
    open(DST, 'w').write(s)
    sys.exit(0)

def gpio_phandle(addr):
    global s
    m = re.search(r'(gpio@%s \{)([^{}]*)(\})' % addr, s)
    if not m:
        raise SystemExit('gpio node %s not found' % addr)
    body = m.group(2)
    ph = re.search(r'phandle = <(0x[0-9a-fA-F]+)>', body)
    if ph:
        return ph.group(1)
    # assign a fresh phandle
    used = [int(x, 16) for x in re.findall(r'phandle = <(0x[0-9a-fA-F]+)>', s)]
    newph = '0x%02x' % (max(used) + 1 if used else 0x01)
    newbody = body.rstrip() + '\n\t\t\tphandle = <%s>;\n\n\t\t' % newph
    s = s[:m.start(2)] + newbody + s[m.end(2):]
    print('assigned phandle %s to gpio@%s' % (newph, addr))
    return newph

ph_dual = gpio_phandle('2007c000')   # gpio0 -> dual red/green pin 8 (B0)
ph_yel  = gpio_phandle('20080000')   # gpio1 -> yellow pin 9 (B1)
print('phandles: dual=%s yellow=%s' % (ph_dual, ph_yel))

node = '''
\t/* V19LED: xmio status LEDs (dual rg @ gpio0_B0, yellow @ gpio1_B1) */
\txmio-leds {
\t\tcompatible = "gpio-leds";

\t\tstatus-led {
\t\t\tlabel = "xmio:red-green:status";
\t\t\tgpios = <{DUAL} 8 0x00>;
\t\t\tdefault-state = "on";
\t\t\tlinux,default-trigger = "heartbeat";
\t\t};

\t\tio-led {
\t\t\tlabel = "xmio:yellow:io";
\t\t\tgpios = <{YEL} 9 0x00>;
\t\t\tdefault-state = "off";
\t\t};
\t};
'''.replace('{DUAL}', ph_dual).replace('{YEL}', ph_yel)

# insert as last root-level node (before final root close)
idx = s.rfind('\n};')
if idx < 0:
    raise SystemExit('root close not found')
s = s[:idx] + '\n' + node + s[idx:]

open(DST, 'w').write(s)
print('V19LED_OK written to', DST)
