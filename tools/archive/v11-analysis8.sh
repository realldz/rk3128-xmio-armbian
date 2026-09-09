#!/usr/bin/env bash
exec > /workspace/work/v11-analysis8.log 2>&1
K=/vol/kernel-src

echo "===== rk_nand_blk.c: device lock implementation ====="
sed -n '145,180p' $K/drivers/rk_nand/rk_nand_blk.c

echo "===== rk_nand_blk.c: rk_nand_blktrans_work body (request processing) ====="
sed -n '395,468p' $K/drivers/rk_nand/rk_nand_blk.c

echo "===== initramfs: scripts/init-top contents ====="
ls -la /tmp/initrd/scripts/init-top/
for f in /tmp/initrd/scripts/init-top/*; do echo "----- $f"; cat "$f"; done

echo "===== initramfs /init lines 195-235 (udevd start context) ====="
sed -n '195,235p' /tmp/initrd/init

echo "===== initramfs /init lines 236-268 (premount/mountroot) ====="
sed -n '236,268p' /tmp/initrd/init
echo V11_ANALYSIS8_DONE
