#!/usr/bin/env bash
exec > /workspace/work/v17-analysis14.log 2>&1
echo '=== nandc node in planb v17 dts ==='
grep -n -A10 'nandc@10500000\|nand@10500000' /workspace/work/xmio-planb-v17.dts | head -20
echo
echo '=== nandc node in STOCK dts ==='
grep -n -B2 -A10 '10500000' /workspace/work/stock-dtbs/rk312x-stock.dts | head -30
echo
echo '=== probe: irq request + failure handling ==='
grep -n -B3 -A8 'platform_get_irq\|request_irq\|IORESOURCE_IRQ' /vol/kernel-src/drivers/rk_nand/rk_nand_base.c | head -50
echo
echo '=== rk_add_timer timeout value ==='
sed -n '/static void rk_add_timer/,/^}/p' /vol/kernel-src/drivers/rk_nand/rk_nand_base.c
echo
echo '=== timer period / jiffies constants near it ==='
grep -n 'msecs_to_jiffies\|HZ\|timeout' /vol/kernel-src/drivers/rk_nand/rk_nand_base.c | head -12
