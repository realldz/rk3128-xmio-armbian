#!/usr/bin/env bash
exec > /workspace/work/v17-analysis16.log 2>&1
echo '=== mainline CRU driver: nandc clocks ==='
grep -n 'nandc' /vol/kernel-src/drivers/clk/rockchip/clk-rk3128.c
echo
echo '=== GATE offset/bit for HCLK_NANDC 453 and SCLK_NANDC 67 ==='
grep -n -B2 -A2 'nandc' /vol/kernel-src/drivers/clk/rockchip/clk-rk3128.c | head -20
echo
echo '=== is rk_nandc_irq_init ever CALLED? ==='
grep -n 'rk_nandc_irq_init' /vol/kernel-src/drivers/rk_nand/*.c
echo
echo '=== irq enable in blob (string) ==='
grep -c 'NANDC_INTEN\|int_en\|INTR' /vol/kernel-src/drivers/rk_nand/rk_ftlv5_arm32.S
echo
echo '=== stock dts: cru phandles 0x12 0x09 0x0f what are they? ==='
grep -n 'phandle = <0x12>;\|phandle = <0x09>;\|phandle = <0x0f>;' /workspace/work/stock-dtbs/rk312x-stock.dts | head -6
grep -n -B4 'phandle = <0x09>;' /workspace/work/stock-dtbs/rk312x-stock.dts | head -12
