#!/usr/bin/env python3
# v19-analysis7.py — map pinctrl groups -> pins, devices -> groups,
# compute safe probe candidates (exclude pins of ACTIVE devices).
import re, sys

s = open('/workspace/work/xmio-planb-v17.dts').read()

# 1. collect pinctrl group nodes: name -> (phandle, pins)
groups = {}
# group nodes look like:  "\t\t\tname {\n ... rockchip,pins = <...>; ... phandle = <0xNN>;"
for m in re.finditer(r'\n\t\t\t([a-zA-Z0-9_-]+) \{([^{}]*)\}', s):
    name, body = m.group(1), m.group(2)
    pm = re.search(r'rockchip,pins\s*=\s*<([^>]+)>', body)
    ph = re.search(r'phandle = <(0x[0-9a-fA-F]+)>', body)
    if pm:
        vals = [int(x, 0) for x in pm.group(1).split()]
        pins = []
        i = 0
        # rk pin entries: bank pin mux pull [drive] -> walk: entry starts when
        # vals[i] is a bank (0..3) and vals[i+1] < 32
        while i < len(vals) - 1:
            if vals[i] <= 3 and vals[i+1] < 32:
                pins.append((vals[i], vals[i+1]))
                j = i + 2
                # skip mux/pull/drive cells until next plausible bank,pin
                while j < len(vals) - 1:
                    if vals[j] <= 3 and vals[j+1] < 32:
                        break
                    j += 1
                i = j
            else:
                i += 1
        groups[name] = (ph.group(1) if ph else None, pins)

# 2. device nodes: pinctrl-0 phandles + status
devices = []
for m in re.finditer(r'\n\t([a-zA-Z0-9_@.-]+) \{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}', s):
    name, body = m.group(1), m.group(2)
    st = re.search(r'status = "([a-z]+)"', body)
    status = st.group(1) if st else 'okay'
    phs = re.findall(r'pinctrl-0\s*=\s*<([^>]+)>', body)
    if phs:
        devices.append((name, status, [p.strip() for p in phs[0].split()]))

print('=== groups found:', len(groups))
print('=== devices using pinctrl ===')
active_pins = set()
for name, status, phs in devices:
    used = [g for g, (ph, pins) in groups.items() if ph in phs]
    print('%-24s %-9s %s' % (name, status, ','.join(used)))
    if status == 'okay':
        for g in used:
            for (b, p) in groups[g][1]:
                active_pins.add(b * 32 + p)

# i2c0 = pmic (disabled node but DO NOT toggle its pins)
for name, status, phs in devices:
    if name.startswith('i2c@2002d000') or name.startswith('i2c@2002e000'):
        for g in [g for g, (ph, pins) in groups.items() if ph in phs]:
            for (b, p) in groups[g][1]:
                active_pins.add(b * 32 + p)

allpins = set(range(128))
safe = sorted(allpins - active_pins)
print()
print('=== active-claimed pins (excluded): %d ===' % len(active_pins))
print('=== SAFE probe candidates: %d ===' % len(safe))
banks = {}
for n in safe:
    banks.setdefault(n // 32, []).append(n % 32)
L = 'ABCD'
for b, ns in sorted(banks.items()):
    print('gpio%d (%d):' % (b, len(ns)), ' '.join('%d:%d%s%d' % (b, p, L[p//8], p%8) for p in ns))
