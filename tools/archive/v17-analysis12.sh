#!/usr/bin/env bash
exec > /workspace/work/v17-analysis12.log 2>&1
cd /vol/kernel-src/drivers/clocksource
echo '=== rk_clksrc_init FULL (263-310) ==='
sed -n '263,310p' timer-rockchip.c
echo
echo '=== any request_irq in file ==='
grep -n 'request_irq\|request_percpu' timer-rockchip.c
echo
echo '=== clkevt regs path: TIMER_CONTROL_REG3288 offset ==='
grep -n 'TIMER_CONTROL_REG\|TIMER_LOAD_COUNT\|0x10\|0x14' timer-rockchip.c | head -8
echo
echo '=== gic spi numbering: stock dts timer0 irq neighbours ==='
grep -n -B2 -A3 'interrupts = <0x00 0x1c 0x04>\|interrupts = <0x00 0x1d 0x04>' /workspace/work/stock-dtbs/rk312x-stock.dts | head -20
