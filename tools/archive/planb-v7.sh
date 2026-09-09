#!/usr/bin/env bash
# Plan B v7: parameter-only — blacklist the hanging rockchip_cpuinfo_init
# (its probe reads efuse via nvmem and hangs silently; cpuinfo is cosmetic)
exec > /workspace/work/planb-v7.log 2>&1
set -e
OUT=/workspace/output/planb-stock-uboot

echo "=== 1. parameter v7 ==="
python3 - "$OUT/parameter.txt" <<'EOF'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
assert 'initcall_blacklist' not in t
t = t.replace('keep_bootcon initcall_debug ignore_loglevel',
              'keep_bootcon initcall_debug initcall_blacklist=rockchip_cpuinfo_init ignore_loglevel')
assert 'initcall_blacklist=rockchip_cpuinfo_init' in t
open(p, 'w', encoding='utf-8').write(t)
print('parameter v7 written')
EOF
grep -o 'initcall_blacklist=[a-z_]*' "$OUT/parameter.txt"

echo "=== 2. checksums ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt uboot-stock.img misc.img baseparamer-720P.img \
  resource.img resource-baseline.img boot.img rk3128-xmio-planb.dtb \
  "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'

echo "=== 3. bundle ==="
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
echo PLANB_V7_DONE
