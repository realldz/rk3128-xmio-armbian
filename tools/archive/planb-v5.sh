#!/usr/bin/env bash
# Plan B v5: parameter-only — keep_bootcon + ttyS0 as preferred console
exec > /workspace/work/planb-v5.log 2>&1
set -e
OUT=/workspace/output/planb-stock-uboot

echo "=== 1. parameter v5 ==="
python3 - "$OUT/parameter.txt" <<'EOF'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read().splitlines()
cmd = [l for l in t if l.startswith('CMDLINE:')][0]
old = 'console=ttyS0,115200 console=ttyS1,115200 console=ttyS2,115200 console=tty1'
new = 'console=ttyS1,115200 console=ttyS2,115200 console=tty1 console=ttyS0,115200'
assert old in cmd, 'console order marker missing'
cmd = cmd.replace(old, new)
assert 'keep_bootcon' not in cmd
cmd = cmd.replace('ignore_loglevel', 'keep_bootcon ignore_loglevel')
out = [l if not l.startswith('CMDLINE:') else cmd for l in t]
open(p, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('parameter v5 written')
EOF
grep CMDLINE "$OUT/parameter.txt"

echo "=== 2. checksums (parameter-only change) ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt uboot-stock.img misc.img baseparamer-720P.img \
  resource.img resource-baseline.img boot.img rk3128-xmio-planb.dtb \
  "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'

echo "=== 3. bundle refresh ==="
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
echo PLANB_V5_DONE
