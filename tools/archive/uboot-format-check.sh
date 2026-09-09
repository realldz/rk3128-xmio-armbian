#!/bin/bash
# uboot-format-check.sh — so sánh format 3 file uboot: raw vs loaderimage header
set -uo pipefail
echo "=== 32 bytes đầu mỗi file ==="
for f in /workspace/work/stock-rkunpack/uboot.img \
         /workspace/output/nand-flash/uboot.img \
         /vol/uboot-build/uboot-new.img; do
  echo "-- $f ($(stat -c%s "$f") bytes)"
  od -A x -t x1z -N 32 "$f"
done
echo
echo "=== thử loaderimage --unpack trên stock 1MiB ==="
/vol/rkbin/tools/loaderimage --unpack --uboot /workspace/work/stock-rkunpack/uboot.img /tmp/stock-unpack.bin 2>&1 || echo ">>> FAIL = stock KHÔNG có header loaderimage (raw)"
ls -l /tmp/stock-unpack.bin 2>/dev/null || true
echo
echo "=== mirror check: 512K đầu == 512K sau? (stock) ==="
if cmp -s -n 524288 <(dd if=/workspace/work/stock-rkunpack/uboot.img bs=512K count=1 2>/dev/null) <(dd if=/workspace/work/stock-rkunpack/uboot.img bs=512K skip=1 count=1 2>/dev/null); then
  echo "stock: 2 mirror 512K GIỐNG NHAU (raw format 2014)"
else
  echo "stock: 2 nửa KHÁC nhau"
fi
echo
echo "=== kích thước partition uboot theo parameter ==="
grep -o '0x00002000@0x00002000(uboot)[^,]*' /workspace/output/planb-stock-uboot/parameter.txt
grep -o '0x00002000@0x00002000(uboot)[^,]*' /workspace/output/nand-flash/parameter.txt
echo "0x2000 sectors * 512 = $((0x2000 * 512)) bytes"
