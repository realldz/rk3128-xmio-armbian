#!/usr/bin/env bash
exec > /workspace/work/v19-analysis3.log 2>&1
echo '=== GPIO sysfs available in current kernel? ==='
grep -E 'CONFIG_GPIO_SYSFS|CONFIG_GPIO_CDEV' /vol/kernel-build/.config
echo
echo '=== stock uboot: LED hints ==='
strings /workspace/output/planb-stock-uboot/uboot-stock.img | grep -iE 'led' | head -10
echo '(done uboot strings)'
echo
echo '=== build candidate pin list: all 128 minus pins claimed in planb dts ==='
python3 - <<'EOF'
import re
s = open('/workspace/work/xmio-planb-v17.dts').read()
used = set()
for m in re.finditer(r'rockchip,pins\s*=\s*<([^>]+)>', s):
    vals = [int(x, 0) for x in m.group(1).split()]
    # entries: bank pin mux pull, optional extra (power) cell pairs
    i = 0
    while i + 1 < len(vals):
        bank, pin = vals[i], vals[i+1]
        used.add(bank * 32 + pin)
        i += 4 if len(vals) - i >= 4 and vals[i+2] < 4 else 4
    # note: pairs may include a 5th cell (drive strength) in rk format:
    # bank pin mux pull drive? -> entries are 4 or 5 cells; regex fallback below
# safer: rk pin format entries are (bank, pin, fn, pull[, drive]) so step unknown;
# redo with robust parse: entries delimited, each starts with bank<4, pin<32
used = set()
for m in re.finditer(r'rockchip,pins\s*=\s*<([^>]+)>', s):
    vals = [int(x, 0) for x in m.group(1).split()]
    i = 0
    while i < len(vals):
        bank, pin = vals[i], vals[i+1]
        used.add(bank * 32 + pin)
        # find next entry: next cell that looks like a bank (0..3) followed by pin<32
        j = i + 2
        while j < len(vals):
            if vals[j] <= 3 and j + 1 < len(vals) and vals[j+1] < 32:
                break
            j += 1
        i = j
cands = [n for n in range(128) if n not in used]
print("excluded(claimed):", len(used))
print("candidates:", len(cands))
banks = {}
for n in cands:
    banks.setdefault(n // 32, []).append(n)
for b, ns in sorted(banks.items()):
    print("gpio%d (%d pins):" % (b, len(ns)), " ".join(str(n) for n in ns))
EOF
