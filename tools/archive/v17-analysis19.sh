#!/usr/bin/env bash
exec > /workspace/work/v17-analysis19.log 2>&1
echo '=== kernel thumb2? ==='
grep -E 'CONFIG_THUMB2_KERNEL|CONFIG_ARM=y|CONFIG_CPU_V7' /vol/kernel-build/.config | head -5
echo
echo '=== which blobs are linked into vmlinux (zftl vs ftlv5 vs v7) ==='
nm /vol/kernel-build/vmlinux 2>/dev/null | grep -iE '(zftl|ftlv5|ftl_init|FtlInit|FtlWrite|FtlRead)' | head -20
echo
echo '=== FTL version string in each blob source ==='
grep -c '5\.0\.63' /vol/kernel-src/drivers/rk_nand/rk_ftlv5_arm32.S /vol/kernel-src/drivers/rk_nand/rk_zftl_arm32.S /vol/kernel-src/drivers/rk_nand/rk_ftl_arm_v7_thumb.S 2>/dev/null
echo
echo '=== base.c: handler + flags + hack (283-335) ==='
sed -n '283,335p' /vol/kernel-src/drivers/rk_nand/rk_nand_base.c
echo
echo '=== does live-family blob enable INTEN? grep int enable writes ==='
grep -n 'INTEN\|int_en\|INT_EN' /vol/kernel-src/drivers/rk_nand/rk_ftl_arm_v7_thumb.S /vol/kernel-src/drivers/rk_nand/rk_zftl_arm32.S 2>/dev/null | head -5
