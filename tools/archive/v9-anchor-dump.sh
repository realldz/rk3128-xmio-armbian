#!/usr/bin/env bash
python3 - <<'EOF'
import re
src = open('/vol/kernel-src/drivers/clocksource/arm_arch_timer.c', encoding='utf-8', newline='').read()
nd='if (!arch_timer_ppi[arch_timer_uses_ppi]) {'
for m in re.finditer(re.escape(nd), src):
    i=m.start()
    print('---- occurrence at', i)
    print(repr(src[i-260:i+60]))
# find enclosing function names
for m in re.finditer(re.escape(nd), src):
    j = src.rfind('static int __init', 0, m.start())
    print('enclosing:', repr(src[j:j+60]))
EOF
