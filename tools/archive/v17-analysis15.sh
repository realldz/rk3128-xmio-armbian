#!/usr/bin/env bash
exec > /workspace/work/v17-analysis15.log 2>&1
echo '=== mainline dtsi nandc node(s) ==='
grep -rn -B2 -A10 'nandc' /vol/kernel-src/arch/arm/boot/dts/rk312x.dtsi /vol/kernel-src/arch/arm/boot/dts/rk3128.dtsi 2>/dev/null | grep -A12 -B2 '10500000' | head -40
echo
echo '=== mainline cru.h: NANDC clock indices ==='
grep -n 'NANDC' /vol/kernel-src/include/dt-bindings/clock/rk3128-cru.h
echo
echo '=== our planb dts: nandc clocks decode (phandle 0x06 = cru?) ==='
grep -n -B3 'phandle = <0x06>;' /workspace/work/xmio-planb-v17.dts | head -8
echo
echo '=== del_timer call sites (who cancels the 20ms hack) ==='
grep -n 'del_timer' /vol/kernel-src/drivers/rk_nand/rk_nand_base.c
echo
echo '=== irq handler functions ==='
grep -n 'irqreturn_t\|rk_nandc_flash_xfer_completed\|rk_nandc_flash_ready' /vol/kernel-src/drivers/rk_nand/rk_nand_base.c | head -10
