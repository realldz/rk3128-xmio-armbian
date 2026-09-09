#!/bin/bash
# bootimg-dtb-check2.sh — carve DTB tu second-blob (RK resource format) + diff gmac vs v23
set -uo pipefail
B=/workspace/output/planb-stock-uboot/boot.img
echo "=== locate resource.img trong workspace ==="
find /workspace/output -name "resource.img" -exec sh -c 'echo "{}: $(md5sum "{}" | cut -c1-32)"' \;

python3 - <<'PY'
blob = open("/tmp/boot-second.dtb","rb").read()
i = blob.find(bytes.fromhex("d00dfeed"))
print("dtb magic at offset", i, "of", len(blob))
open("/tmp/shipped.dtb","wb").write(blob[i:])
PY
dtc -I dtb -O dts -o /tmp/shipped.dts /tmp/shipped.dtb && echo "dtc OK: /tmp/shipped.dts"

echo
echo "=== node ethernet@2008c000 trong DTB SHIPPED (boot.img 5f61edcd) ==="
awk '/ethernet@2008c000 \{/,/^\t\};/' /tmp/shipped.dts

echo
echo "=== status-led + io-led (kiem tra patch LED v24.3) ==="
grep -n -A8 "status-led\|io-led" /tmp/shipped.dts | head -24

echo
echo "=== DIFF shipped DTB vs work/xmio-planb-v23.dts (bo phandle, chi khac biet thuc su) ==="
sed 's/phandle = <[0-9a-fx]*>;//' /tmp/shipped.dts | grep -v '^\s*$' > /tmp/a.norm
sed 's/phandle = <[0-9a-fx]*>;//' /workspace/work/xmio-planb-v23.dts | grep -v '^\s*$' > /tmp/b.norm
diff /tmp/b.norm /tmp/a.norm | head -80
echo "--- (KET THUC DIFF; rong = shipped DTB == v23 reference)"
