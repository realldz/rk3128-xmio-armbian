#!/usr/bin/env bash
exec > /workspace/work/v9-analysis6.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox

echo "===== dw8250_probe full body ====="
F=$K/drivers/tty/serial/8250/8250_dw.c
L=$(grep -n "static int dw8250_probe" $F | cut -d: -f1)
E=$(awk -v s=$L 'NR>=s && /^}/ {print NR; exit}' $F)
echo "dw8250_probe $L..$E"
sed -n "${L},${E}p" $F

echo "===== serial8250_register_8250_port: uart_add_one_port region ====="
F2=$K/drivers/tty/serial/8250/8250_core.c
sed -n '1155,1186p' $F2

echo "===== arch_timer_of_init (arm32 path) ====="
F3=$K/drivers/clocksource/arm_arch_timer.c
L=$(grep -n "arch_timer_arch_of_init\|static int __init arch_timer_of_init" $F3 | head -5)
echo "$L"
L2=$(grep -n "arch_timer_arch_of_init" $F3 | head -1 | cut -d: -f1)
sed -n "$((L2-40)),$((L2+70))p" $F3

echo "===== rockchip_boot_secondary ====="
F4=$K/arch/arm/mach-rockchip/platsmp.c
L=$(grep -n "rockchip_boot_secondary" $F4 | head -2)
echo "$L"
L3=$(grep -n "static int rockchip_boot_secondary" $F4 | cut -d: -f1)
E=$(awk -v s=$L3 'NR>=s && /^}/ {print NR; exit}' $F4)
sed -n "${L3},${E}p" $F4

echo "===== kernel build tree check ====="
ls -d $K/build 2>/dev/null && ls $K/build/.config 2>/dev/null && echo BUILD_TREE_EXISTS
ls -d $K/out 2>/dev/null && echo OUT_EXISTS
ls $K/vmlinux $K/arch/arm/boot/zImage 2>/dev/null && echo IN_TREE_ARTIFACTS

echo "===== planb-build.sh kernel build section (docker pattern) ====="
grep -n "docker\|make\|zImage\|KERNEL_DIR\|O=" /workspace/tools/planb-build.sh | head -30
echo V9_ANALYSIS6_DONE
