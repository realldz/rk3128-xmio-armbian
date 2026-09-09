#!/usr/bin/env bash
exec > /workspace/work/v11-analysis7.log 2>&1
K=/vol/kernel-src

echo "===== queue_rq / request handling in rk_nand_blk.c ====="
grep -n "queue_rq\|nand_gc_thread\|blk_mq_start_request\|blk_mq_end_request\|BLK_MQ_RQ\|wake_up\|wait_event\|wait_for_completion\|spin_lock" $K/drivers/rk_nand/rk_nand_blk.c | head -40

echo "===== queue_rq body ====="
grep -n -B3 -A50 "static blk_status_t.*queue_rq" $K/drivers/rk_nand/rk_nand_blk.c

echo "===== nand_gc_thread body ====="
grep -n -B3 -A70 "static int nand_gc_thread" $K/drivers/rk_nand/rk_nand_blk.c

echo "===== read/write entry (do_request) ====="
grep -n -B3 -A60 "static void do_nand_request\|static void nand_do_request\|void.*do_request" $K/drivers/rk_nand/rk_nand_blk.c | head -100

echo "===== initramfs: udev rules present? ====="
ls /tmp/initrd/lib/udev/rules.d/ 2>/dev/null
echo "----- persistent-storage rule: blkid? -----"
grep -l "blkid" /tmp/initrd/lib/udev/rules.d/* 2>/dev/null
grep -n "blkid" /tmp/initrd/lib/udev/rules.d/60-persistent-storage.rules 2>/dev/null | head

echo "===== initramfs /init: what happens after udevd ====="
grep -n "udevd\|udevadm\|settle\|trigger\|Loading essential\|mountroot\|local-top\|init-top\|run_scripts" /tmp/initrd/init | head -30

echo "===== /conf/modules (essential drivers list) ====="
cat /tmp/initrd/conf/modules 2>/dev/null

echo "===== scripts/init-top/all (post-udev steps) ====="
cat /tmp/initrd/scripts/init-top/all 2>/dev/null | head -40
echo V11_ANALYSIS7_DONE
