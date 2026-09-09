#!/usr/bin/env bash
exec > /workspace/work/v9-analysis13.log 2>&1

echo "===== 8250_core.c 995-1135 ====="
sed -n '995,1135p' /vol/kernel-src/drivers/tty/serial/8250/8250_core.c

echo "===== platsmp.c boot_secondary full 100-160 + 270-310 ====="
sed -n '100,160p' /vol/kernel-src/arch/arm/mach-rockchip/platsmp.c
sed -n '270,310p' /vol/kernel-src/arch/arm/mach-rockchip/platsmp.c

echo "===== planb-v8.sh boot.img section ====="
grep -n "mkbootimg\|zImage\|initrd\|resource" /workspace/tools/planb-v8.sh | head -20

echo "===== build_kernel.sh make invocations ====="
grep -n "make \|CROSS_COMPILE\|O=" /vol/scripts/build_kernel.sh | head -20

echo "===== timer-rockchip rk_timer_probe body 130-200 ====="
sed -n '130,200p' /vol/kernel-src/drivers/clocksource/timer-rockchip.c
echo V9_ANALYSIS13_DONE
