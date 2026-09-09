#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. context around rk_nand_blk.c:860-890 (ifdef?) ==="
sed -n '858,895p' /vol/kernel-src/drivers/rk_nand/rk_nand_blk.c
echo "=== 2. rk_vendor symbols in current vmlinux ==="
nm /vol/kernel-build/vmlinux | grep -E 'rk_vendor_(read|write|register)|rk_ftl_vendor' | head -8
echo "=== 3. eth_random needed symbols ok ==="
nm /vol/kernel-build/vmlinux | grep -E ' T (eth_random_addr|is_valid_ether_addr)$' | head -4
