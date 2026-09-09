#!/usr/bin/env bash
echo "=== CROSS_COMPILE in env ==="
env | grep -i cross || echo '(none)'
echo "=== Makefile CROSS_COMPILE logic ==="
grep -n "CROSS_COMPILE" /vol/uboot-sb/Makefile | head -8
grep -rn "CROSS_COMPILE" /vol/uboot-sb/scripts/Makefile.autoconf 2>/dev/null | head -5
echo "=== sandbox ld rule ==="
grep -n "LD " /vol/uboot-sb/arch/sandbox/config.mk 2>/dev/null || ls /vol/uboot-sb/arch/sandbox/
