#!/usr/bin/env bash
exec > /workspace/work/v10-verify1.log 2>&1
B=/vol/kernel-build

echo "===== build log: mach-rockchip + LD vmlinux ====="
grep -n "mach-rockchip\|LD.*vmlinux" /workspace/work/v10-build.log | head -20

echo "===== nm rockchip symbols in vmlinux ====="
nm $B/vmlinux | grep -i "rockchip\|rk3036" | head -20

echo "===== strings check ====="
strings $B/vmlinux | grep "V10DIAG\|Rockchip (Device Tree)" | head

echo "===== built-in.a members ====="
ar t $B/arch/arm/mach-rockchip/built-in.a

echo "===== does vmlinux include mach-rockchip section? ====="
nm $B/vmlinux | grep -c "rockchip" || true

echo "===== arch/arm/Makefile final state ====="
grep -n -B1 -A1 "CONFIG_ARCH_ROCKCHIP)" $B/../kernel-src/arch/arm/Makefile 2>/dev/null || grep -n -B1 -A1 "CONFIG_ARCH_ROCKCHIP)" /vol/kernel-src/arch/arm/Makefile

echo "===== .config ARCH_ROCKCHIP ====="
grep -n "CONFIG_ARCH_ROCKCHIP" $B/.config

echo "===== make dry-run: would vmlinux relink? ====="
cd /vol/kernel-src
export CROSS_COMPILE=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf- ARCH=arm LOCALVERSION=+
make O=$B V=1 vmlinux 2>&1 | tail -5
echo V10_VERIFY1_DONE
