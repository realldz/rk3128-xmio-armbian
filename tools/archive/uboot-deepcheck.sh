#!/bin/bash
# uboot-deepcheck.sh — kiểm chứng nghi phạm còn lại sau khi v3 câm
set -uo pipefail
echo "############ A. CONFIG_DEBUG_UART_BASE thực tế trong build v3 ############"
grep -n "DEBUG_UART_BASE\|DEBUG_UART_CLOCK\|CONS_INDEX" /vol/uboot-v3-build/.config

echo
echo "############ B. uboot 2017 có đòi TOS/OPTEE sớm (pre-reloc) không? ############"
cd /vol/uboot-v3-src
echo "--- optee trong mach-rockchip + board evb:"
grep -rn "optee\|OPTEE" arch/arm/mach-rockchip/rk3128/ board/rockchip/evb_rk3128/evb-rk3128.c 2>/dev/null | grep -v "\.o:" | head -12
echo "--- optee trong board_init_f / pre-reloc path (common + arch):"
grep -rn "optee_verify\|optee_init\|optee_early" arch/arm/mach-rockchip/ common/ 2>/dev/null | grep -v "\.o:" | head -8
echo "--- secure monitor call sớm (smc):"
grep -rn "optee_smc\|__smc\|optee_invoke_fn" arch/arm/mach-rockchip/ common/ 2>/dev/null | grep -v "\.o:" | head -6

echo
echo "############ C. ai load TOS? loader hay uboot? (chuỗi loader->uboot) ############"
echo "--- trong uboot: có code LOAD trust từ flash không:"
grep -rn "trust.img\|load_trust\|TOS_IMAGE\|TRUST_IMG" common/ arch/arm/mach-rockchip/ include/ 2>/dev/null | grep -v "\.o:" | head -8

echo
echo "############ D. toolchain tác giả (Makefile/make.sh?) ############"
ls /vol/uboot-v3-src/*.sh /vol/uboot-v3-src/Makefile 2>/dev/null
grep -n "CROSS_COMPILE\|toolchain\|linaro" /vol/uboot-v3-src/make.sh 2>/dev/null | head -6

echo
echo "############ E. misc/baseparamer có image dự phòng không (để tính rủi ro Plan C) ############"
ls /workspace/work/stock-rkunpack/Image/ 2>/dev/null | head -20
ls /workspace/work/stock-rkunpack/ 2>/dev/null
