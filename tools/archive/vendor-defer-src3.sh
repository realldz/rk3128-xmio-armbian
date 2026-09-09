#!/bin/bash
# vendor-defer-src3.sh — "deferred probe pending" print site + vendor register + NOTES MAC arc + git log patch
set -uo pipefail
KS=/vol/kernel-src
echo "### 1. 'deferred probe pending' in o dau trong 6.6:"
grep -rn "deferred probe pending" $KS/drivers/base/*.c | head -5
F=$(grep -rln "deferred probe pending" $KS/drivers/base/*.c | head -1)
[ -n "$F" ] && grep -n -B12 "deferred probe pending" "$F" | head -30
echo
echo "### 2. ai dang ky _vendor_read (rk_vendor_register):"
grep -rn "rk_vendor_register\|_vendor_read =" $KS/drivers --include=*.c | head -8
echo
echo "### 3. NOTES: doc 980-1030 (vendor FTL), 1110-1130 (IDB ho), 1538-1560 (69 MAC arc), 1600-1660 (tool):"
sed -n '980,1030p' /workspace/NOTES.md
echo "----"
sed -n '1110,1130p' /workspace/NOTES.md
echo "----"
sed -n '1538,1665p' /workspace/NOTES.md
