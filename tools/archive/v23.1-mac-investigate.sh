#!/usr/bin/env bash
set -uo pipefail
D=/workspace/work/xmio-planb-v23.dts
echo "=== 1. clock-controller / cru node ==="
grep -n 'clock-controller@\|cru@' "$D" | head -6
echo "=== 2. gmac clock phandle refs ==="
grep -n -A20 'ethernet@2008c000' "$D" | grep -E 'clocks|<0x' | head -10
echo "=== 3. phandle defs near cru ==="
grep -n -B2 -A6 'clock-controller@20000000' "$D" | head -20
echo "=== 4. PCLK_EFUSE id 326 = 0x146 in cells? ==="
grep -n '0x146' "$D" | head -5
echo "=== 5. rk3128 cru driver present (for PCLK_EFUSE reg) ==="
ls /vol/kernel-src/drivers/clk/rockchip/ | grep -i '3128\|312x'
grep -n 'PCLK_EFUSE\|326' /vol/kernel-src/drivers/clk/rockchip/rk3128-cru.c 2>/dev/null | head -5
echo "=== 6. rockchip_rk3128_efuse_read fn ==="
grep -n -A30 'static int rockchip_rk3128_efuse_read' /vol/kernel-src/drivers/nvmem/rockchip-efuse.c | head -40
echo "=== 7. REG_EFUSE_CTRL/DOUT ==="
grep -n 'REG_EFUSE_CTRL\|REG_EFUSE_DOUT' /vol/kernel-src/drivers/nvmem/rockchip-efuse.c | head -4
