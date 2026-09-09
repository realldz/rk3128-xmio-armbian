#!/usr/bin/env bash
exec > /workspace/work/sandbox-build4.log 2>&1
set -e
cd /vol/uboot-sb
mkdir -p /vol/uboot-sb/arch/sandbox/include/asm/arch
cp -f /vol/uboot-sb/arch/arm/include/asm/uspinlock.h /vol/uboot-sb/arch/sandbox/include/asm/uspinlock.h
cat > /vol/uboot-sb/arch/sandbox/include/asm/arch/boot_mode.h <<'EOF'
#ifndef SANDBOX_BOOT_MODE_H
#define SANDBOX_BOOT_MODE_H
#define BOOT_BROM_DOWNLOAD 0xEF08A53C
#endif
EOF
# Stub out SDL video support (headless build; the vendor Makefile keeps sdl.o on)
printf '/* SDL support stubbed out for headless sandbox build */\n' > /vol/uboot-sb/arch/sandbox/cpu/sdl.c
# Vendor generic code references Rockchip-only config ints; provide via CFLAGS
# (symbols are invisible in sandbox Kconfig so .config lines would be dropped).
make O=/vol/uboot-sb-build olddefconfig
make -j8 O=/vol/uboot-sb-build KCFLAGS='-Wno-error -DCONFIG_DEBUG_UART_BASE=0 -DCONFIG_DEBUG_UART_SHIFT=0 -DCONFIG_ROCKCHIP_BOOT_MODE_REG=0' CROSS_COMPILE=
ls -la /vol/uboot-sb-build/u-boot
echo SANDBOX_BUILD4_DONE
bash /workspace/tools/sandbox-test.sh
