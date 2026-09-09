#!/bin/bash
# uboot-hwcompat6.sh — xem commit reset-button + mtdparts-export + defconfig tại base A26
set -uo pipefail
cd /vol/uboot-src
echo "############ 1. Commit reset button (62a6711e48) ############"
git show --stat 62a6711e48 | head -14
echo "--- code chinh:"
git show 62a6711e48 | grep -E "^\+" | grep -vE "^\+\+\+" | head -40

echo
echo "############ 2. Commit export mtdparts (53cd91b73c = A26 base) ############"
git show --stat 53cd91b73c | head -12
git show 53cd91b73c | grep -E "^\+" | grep -vE "^\+\+\+" | head -25

echo
echo "############ 3. defconfig rk3128 tai 53cd91b73c ############"
git show 53cd91b73c:configs/rk3128_defconfig > /tmp/defconfig-a26.txt
wc -l /tmp/defconfig-a26.txt
grep -E "DEBUG_UART_BASE|BOOTDELAY|SYS_PROMPT|USING_KERNEL_DTB|NAND_BOOT|RKNAND=|ADC_KEY|GPIO_KEY|DM_KEY|RK_KEY|BOOT_ROCKCHIP|VENDOR_PARTITION" /tmp/defconfig-a26.txt
echo "--- diff defconfig A26-base vs HEAD:"
git diff 53cd91b73c HEAD -- configs/rk3128_defconfig | head -30
