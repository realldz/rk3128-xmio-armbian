#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. exact stock string in A26 tree? ==="
grep -rn "Ethernet MAC address from" /vol/kernel-src/drivers/ /vol/kernel-src/include/ 2>/dev/null | head -5
echo "=== 2. IDBlock refs in rk_nand + rkflash + net ==="
grep -rn -i 'idblock\|id_block\|idblk' /vol/kernel-src/drivers/rk_nand/ /vol/kernel-src/drivers/rkflash/ /vol/kernel-src/drivers/net/ /vol/kernel-src/include/ 2>/dev/null | grep -v '\.S:' | head -15
echo "=== 3. IDB symbols in vmlinux (blob) ==="
nm /vol/kernel-build/vmlinux | grep -i 'idb' | head -10
echo "=== 4. rk_ftl_api.h FULL (blob API surface) ==="
cat /vol/kernel-src/drivers/rk_nand/rk_ftl_api.h
echo "=== 5. rk_nand_base.h FULL ==="
cat /vol/kernel-src/drivers/rk_nand/rk_nand_base.h
echo "=== 6. ioctls exposed by rk_nand_blk ==="
grep -n 'ioctl\|BLK\|_IOW\|_IOR' /vol/kernel-src/drivers/rk_nand/rk_nand_blk.c | head -20
