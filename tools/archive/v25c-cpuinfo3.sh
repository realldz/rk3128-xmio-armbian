#!/usr/bin/env bash
# v25c-cpuinfo3.sh — doc rockchip-cpuinfo.c + config status
set -uo pipefail
cd /vol/kernel-src
echo "=== rockchip-cpuinfo.c (toan bo, 160 dong dau) ==="
sed -n '1,160p' drivers/soc/rockchip/rockchip-cpuinfo.c
echo
echo "=== config ==="
grep -E 'ROCKCHIP_CPUINFO|NVMEM_ROCKCHIP_EFUSE' /vol/kernel-build/.config
echo
echo "=== compatible cua driver ==="
grep -n 'compatible' drivers/soc/rockchip/rockchip-cpuinfo.c
grep -rn 'rockchip,cpuinfo' /workspace/work/xmio-planb-v23.dts || echo "(DTB chua co node cpuinfo)"
