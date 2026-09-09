#!/usr/bin/env bash
exec > /workspace/work/v8-analysis6.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox
C8=$K/drivers/tty/serial/8250/8250_core.c

echo "===== where is uart_add_one_port defined ====="
grep -rn "uart_add_one_port(struct uart_driver" $K/drivers/tty/serial/ | head -3

echo "===== smp.c: failed-to-boot messages + present mask ====="
grep -n "failed to boot\|failed to come online\|set_cpu_present\|setup_max_cpus" $K/arch/arm/kernel/smp.c | head -12

echo "===== rockchip.c: machine + timer init ====="
sed -n '1,60p' $K/arch/arm/mach-rockchip/rockchip.c
grep -n "DT_MACHINE_START\|dt_compat\|init_time\|sgrf\|0x2c\|rv1108\|rk3288" $K/arch/arm/mach-rockchip/rockchip.c | head -20

echo "===== global counter / CNTCR refs in mach-rockchip ====="
grep -rn "CNTCR\|sys_counter\|global.timer\|system.counter\|GEN_TIMER" $K/arch/arm/mach-rockchip/ | head

echo "===== stock dts: timer nodes ====="
grep -n "timer@\|arm,armv7-timer\|rockchip,timer\|dw_apb\|dwapb" /workspace/work/stock-dtbs/rk312x-stock.dts | head -20

echo "===== our v8 dts: timer nodes ====="
grep -n "timer@\|arm,armv7-timer\|rockchip,timer" /workspace/work/xmio-planb-v8.dts | head -20

echo "===== kernel config: timers ====="
grep -n "CONFIG_ARM_ARCH_TIMER\|CONFIG_DW_APB_TIMER\|CONFIG_CLKSRC" /workspace/output/kernel/kernel.config | head -10

echo "===== 8250_core.c: register_8250_port body ====="
sed -n '1017,1186p' $C8
echo V8_ANALYSIS6_DONE
