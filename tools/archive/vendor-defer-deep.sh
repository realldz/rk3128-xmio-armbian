#!/bin/bash
# vendor-defer-deep.sh — doc patch defer + is_rk_vendor_ready + tim backup vendor
set -uo pipefail
KS=/vol/kernel-src
echo "### 1. Toan bo khoi defer trong rk_gmac_probe (sau cho da thay):"
grep -n -A22 "rk_gmac_vendor_defers" $KS/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c | head -34
echo
echo "### 2. is_rk_vendor_ready nam o dau, body gi:"
grep -rn "is_rk_vendor_ready" $KS --include=*.c --include=*.h | head
F=$(grep -rln "bool is_rk_vendor_ready" $KS --include=*.c | head -1)
echo "== body ($F):"
[ -n "$F" ] && sed -n "/bool is_rk_vendor_ready/,/^}/p" "$F"
echo
echo "### 3. rk_vendor_ready flag duoc set o dau:"
grep -rn "rk_vendor_ready\|vendor_ready = \|vendor_ready=" $KS --include=*.c | grep -v dwmac | head
echo
echo "### 4. Backup vendor / tool vendor trong workspace:"
find /workspace -iname "*vendor*" 2>/dev/null | head -15
echo
echo "### 5. Ghi chu NOTES ve vendor storage vi tri + tool:"
grep -n -i "vendor" /workspace/NOTES.md | grep -iE "0x14000|backup|tool|4kb|idb|store" | head -20
