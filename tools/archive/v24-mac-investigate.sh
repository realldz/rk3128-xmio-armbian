#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. RK3288_* macros in rockchip-efuse.c ==="
sed -n '1,80p' /vol/kernel-src/drivers/nvmem/rockchip-efuse.c | grep -n 'define\|include'
echo "=== 2. rk3128-efuse of_match data (which read fn) ==="
sed -n '496,545p' /vol/kernel-src/drivers/nvmem/rockchip-efuse.c
echo "=== 3. rk3288 read fn (sequence to replicate) ==="
grep -n -A40 'static int rockchip_rk3288_efuse_read' /vol/kernel-src/drivers/nvmem/rockchip-efuse.c | head -55
echo "=== 4. dwmac-rk includes (delay/io present?) ==="
sed -n '1,40p' /vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c | grep -n 'include'
