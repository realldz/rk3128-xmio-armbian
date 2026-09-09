#!/bin/bash
# uboot-loader-compare.sh — so sánh 2 loader: stock V2.25 vs v2.12.263
set -uo pipefail
A=/workspace/work/stock-rkunpack/rk3128MiniLoaderAll\(L\)_V2.25_ink.bin
B=/workspace/output/nand-flash/rk3128_loader_v2.12.263.bin
echo "=== sizes ==="
ls -l "$A" "$B"
echo
echo "=== version strings ==="
for f in "$A" "$B"; do
  echo "-- $(basename "$f")"
  strings "$f" | grep -aiE "loader.*2\.[0-9]+|2\.[0-9]+\.[0-9]+|20[0-9][0-9]-[0-9][0-9]|build.*time|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec" | grep -av "^\[" | head -8
done
echo
echo "=== rk signature / header 4 byte dau ==="
for f in "$A" "$B"; do od -A x -t x1z -N 16 "$f"; done
echo
echo "=== tag/chuỗi đặc trưng ==="
for f in "$A" "$B"; do
  echo "-- $(basename "$f")"
  for s in "LOADER  " "RK31" "rk3128" "trust" "TRUST" "optee" "OPTEE" "uboot" "BOOT1" "parameter"; do
    printf '  %-10s: ' "$s"; grep -ac "$s" "$f" 2>/dev/null || echo 0
  done
done
