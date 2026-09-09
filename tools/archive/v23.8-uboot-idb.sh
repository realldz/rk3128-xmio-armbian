#!/usr/bin/env bash
set -uo pipefail
U=/vol/uboot-sb
echo "=== 1. tree top ==="
ls "$U" | head -20
echo "=== 2. IDB / chipinfo / SN read-write code ==="
grep -rln -i 'idblock\|IdBlock\|chip.?info\|IDBInfo' "$U" --include='*.c' --include='*.h' 2>/dev/null | head -12
echo "=== 3. SN / MAC in IDB ==="
grep -rn -i 'sn\[\|chip_info\|chipinfo\|SN_IDB\|MAC.*idb\|idb.*mac' "$U"/board/rockchip "$U"/drivers "$U"/common 2>/dev/null | grep -v Binary | head -20
echo "=== 4. storage layer: ReadIdBlock/WriteIdBlock ==="
grep -rn 'IdBlock\|IDBLOCK\|IdbBlock' "$U" --include='*.c' --include='*.h' 2>/dev/null | grep -v Binary | head -20
echo "=== 5. vendor storage in uboot (uboot-era vendor storage may differ) ==="
grep -rln 'vendor_storage\|vendorstorage\|rk_vendor' "$U" --include='*.c' --include='*.h' 2>/dev/null | head -8
