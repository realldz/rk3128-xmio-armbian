#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. uapi header (struct + ioctl cmds) ==="
cat /vol/kernel-src/include/uapi/misc/rkflash_vendor_storage.h 2>/dev/null || find /vol/kernel-src/include -name '*vendor*' | head
echo "=== 2. rk_nand_base.c includes + misc init body ==="
sed -n '1,40p' /vol/kernel-src/drivers/rk_nand/rk_nand_base.c
sed -n '255,320p' /vol/kernel-src/drivers/rk_nand/rk_nand_base.c
echo "=== 3. blob ioctl expectations (VENDOR_REQ in vmlinux strings?) ==="
grep -rn 'RK_VENDOR_REQ\|VENDOR_READ_IO\|VENDOR_WRITE_IO' /vol/kernel-src/drivers/ /vol/kernel-src/include/ 2>/dev/null | grep -v Binary | head -10
