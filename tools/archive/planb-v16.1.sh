#!/usr/bin/env bash
# planb-v16.1.sh — force HDMI connector enabled via kernel cmdline.
# Connector card0-HDMI-A-1 exists but never reports a display (HPD/EDID
# path unverified on this board). video=HDMI-A-1:1920x1080@60e forces
# the connector on with 1080p60 regardless of hotplug/EDID. If output
# lights up: phy+encoder chain OK, remaining bug is only HPD/EDID.
# Flash: parameter.txt -> 0x0. No kernel/dtb change.
set -euo pipefail
OUT=/workspace/output/planb-stock-uboot

cp -f "$OUT/parameter.txt" "$OUT/parameter.txt.v16.bak"
python3 - "$OUT/parameter.txt" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
assert 'video=HDMI-A-1' not in s, 'already patched'
anchor = ' rootfstype=ext4 mtdparts='
assert s.count(anchor) == 1, 'cmdline anchor missing'
s = s.replace(anchor,
              ' rootfstype=ext4 video=HDMI-A-1:1920x1080@60e mtdparts=')
open(p, 'w', encoding='utf-8', newline='').write(s)
print('cmdline patched')
EOF
grep '^CMDLINE:' "$OUT/parameter.txt" | head -c 430; echo

echo "=== hashes + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.v14diag.bak parameter.txt.v16.bak \
  uboot-stock.img misc.img baseparamer-720P.img resource.img \
  resource-baseline.img boot.img rk3128-xmio-planb.dtb \
  "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
md5sum "$OUT/parameter.txt"
echo PLANB_V16_1_DONE
