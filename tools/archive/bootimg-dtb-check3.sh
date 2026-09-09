#!/bin/bash
# bootimg-dtb-check3.sh — carve DTB (raw/gzip) tu resource.img + boot.img, decompile, diff gmac
set -uo pipefail
R=/workspace/output/planb-stock-uboot/resource.img
B=/workspace/output/planb-stock-uboot/boot.img

python3 - <<'PY'
import re, gzip, io, os

def carve(data, name):
    offs = [m.start() for m in re.finditer(b"\xd0\x0d\xfe\xed", data)]
    print(f"{name}: d00dfeed x{len(offs)} at {offs[:6]}")
    if not offs:
        # gzip?
        for m in re.finditer(b"\x1f\x8b\x08", data):
            try:
                raw = gzip.decompress(data[m.start():m.start()+200000])
                if raw[:4] == b"\xd0\x0d\xfe\xed":
                    print(f"  gzip-DTB at {m.start()} -> {len(raw)}B")
                    open(f"/tmp/{name}.dtb","wb").write(raw)
                    return True
            except Exception:
                pass
        return False
    open(f"/tmp/{name}.dtb","wb").write(data[offs[0]:])
    return True

r = open("/workspace/output/planb-stock-uboot/resource.img","rb").read()
print("resource.img:", len(r), "B, head:", r[:32].hex())
ok = carve(r, "res")
if not ok:
    # in cau truc resource header de hieu format
    print("first 96B:", r[:96])
b = open("/workspace/output/planb-stock-uboot/boot.img","rb").read()
ok2 = carve(b, "boot")
PY

for f in /tmp/res.dtb /tmp/boot.dtb; do
  [ -f "$f" ] && dtc -I dtb -O dts -o "${f%.dtb}.dts" "$f" && echo "DTC OK: $f"
done

DTS=$(ls /tmp/res.dts /tmp/boot.dts 2>/dev/null | head -1)
if [ -n "$DTS" ]; then
  echo
  echo "=== gmac node trong DTB SHIPPED ($DTS) ==="
  awk '/ethernet@2008c000 \{/,/^\t\};/' "$DTS"
  echo
  echo "=== status-led / io-led ==="
  grep -n -A7 "status-led\|io-led" "$DTS" | head -22
  echo
  echo "=== DIFF shipped vs v23 (bo phandle) ==="
  sed 's/phandle = <[0-9a-fx]*>;//' "$DTS" | grep -v '^[[:space:]]*$' > /tmp/a.norm
  sed 's/phandle = <[0-9a-fx]*>;//' /workspace/work/xmio-planb-v23.dts | grep -v '^[[:space:]]*$' > /tmp/b.norm
  diff /tmp/b.norm /tmp/a.norm > /tmp/d.diff
  wc -l /tmp/d.diff
  head -60 /tmp/d.diff
fi
