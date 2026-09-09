#!/bin/bash
# uboot-hwcompat2.sh — git lineage + console config + serial nodes + stock dtb retry
set -uo pipefail
echo "############ A. Git lineage: 53cd91b73c (A26 base) vs HEAD 218938c ############"
cd /vol/uboot-src
git cat-file -t 53cd91b73c 2>&1 || echo "COMMIT_NOT_IN_REPO"
git log --oneline --all | head -5
git merge-base --is-ancestor 53cd91b73c HEAD 2>/dev/null && echo "53cd91 IS ancestor of HEAD" || echo "53cd91 NOT ancestor (or unknown)"

echo
echo "############ B. DEBUG_UART trong .config cuoi cung ############"
grep -E "DEBUG_UART" /vol/uboot-build/.config

echo
echo "############ C. Serial nodes trong DTB uboot-v1 ############"
grep -n "serial" /tmp/ubv1.dts | head -20
echo "--- status quanh serial:"
awk '/serial[0-9]*@2006[0468]000/,/};/' /tmp/ubv1.dts | grep -E "serial|status|compatible|pinctrl|reg =" | head -30

echo
echo "############ D. Stock dtb retry ############"
ls -l /tmp/stockub.dtb 2>/dev/null
od -A d -t x1 -N 32 /tmp/stockub.dtb 2>/dev/null | head -3
dtc -I dtb -O dts /tmp/stockub.dtb > /tmp/stockub.dts 2>&1 || echo "DTC_ERR: $(head -2 <<< "$(dtc -I dtb -O dts /tmp/stockub.dtb 2>&1 >/dev/null)")"
ls -l /tmp/stockub.dts 2>/dev/null
echo "--- tat ca dtb magic trong payload stock:"
python3 - <<'EOF'
data = open('/tmp/stock-unpack.bin','rb').read()
magic = bytes([0xd0,0x0d,0xfe,0xed])
pos, hits = 0, []
while True:
    idx = data.find(magic, pos)
    if idx < 0: break
    hits.append(idx)
    pos = idx + 4
print("dtb magic offsets:", hits[:10], "total:", len(hits))
EOF

echo
echo "############ E. bootcmd/battery/charge trong DTB uboot-v1 ############"
grep -n -A8 "charge\|battery\|pmic" /tmp/ubv1.dts | head -30
