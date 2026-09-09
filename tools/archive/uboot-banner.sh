#!/bin/bash
set -uo pipefail
for f in /workspace/output/nand-flash/uboot.img /vol/uboot-build/u-boot.bin; do
  echo "== $f"
  grep -ao 'U-Boot 20[0-9.]*[0-9a-zA-Z .:-]*' "$f" | head -1 || echo "(no banner)"
  grep -ao 'RK3128 >>' "$f" | head -1 || echo "(no prompt)"
done
