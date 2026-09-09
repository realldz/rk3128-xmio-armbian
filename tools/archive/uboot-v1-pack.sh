#!/bin/bash
# uboot-v1-pack.sh — pack fresh u-boot.bin into uboot.img using loaderimage, mirroring A26 header params
set -euo pipefail
LB=/vol/rkbin/tools/loaderimage
A26=/workspace/output/nand-flash/uboot.img        # A26 2017.09 reference
BIN=/vol/uboot-build/u-boot.bin
OUT=/vol/uboot-build/uboot-new.img
TMP=/vol/uboot-build/unpack-a26

echo "=== unpack A26 to read header params ==="
rm -rf "$TMP"; mkdir -p "$TMP"
"$LB" --unpack --uboot "$A26" "$TMP/uboot-a26.bin" || "$LB" --unpack "$A26" "$TMP/uboot-a26.bin" || echo "UNPACK_FAILED"
ls -l "$TMP" || true

echo "=== pack fresh ==="
rm -f "$OUT"
"$LB" --pack --uboot "$BIN" "$OUT" 0x60000000
ls -l "$OUT"
echo "=== pad to 4MiB like A26 ==="
SZ=$(stat -c%s "$OUT")
if [ "$SZ" -lt 4194304 ]; then
  dd if=/dev/zero bs=1 count=$((4194304-SZ)) >> "$OUT"
fi
ls -l "$OUT"
md5sum "$OUT" "$A26" "$BIN"
echo "=== headers ==="
xxd -l 64 "$OUT"; echo ---; xxd -l 64 "$A26"
