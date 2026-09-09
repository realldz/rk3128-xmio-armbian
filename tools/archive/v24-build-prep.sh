#!/usr/bin/env bash
set -uo pipefail
U=/vol/uboot-sb
echo "=== 1. A26 uboot: does it auto-set ethaddr from vendor LAN_MAC_ID? ==="
grep -rn 'LAN_MAC_ID' "$U"/arch/arm/mach-rockchip/ "$U"/board/rockchip/ "$U"/net/ "$U"/cmd/ 2>/dev/null | head -6
grep -rn -B4 -A12 'LAN_MAC_ID' "$U"/arch/arm/mach-rockchip/board.c 2>/dev/null | head -25
echo "=== 2. vendor.c: which function wraps writes at 907/975/1019/1032 ==="
awk 'NR>=880 && NR<=920' "$U"/arch/arm/mach-rockchip/vendor.c
echo "=== 3. kernel-src patch target: exact block ==="
grep -n -B2 -A8 'rknand vendor storage init' /vol/kernel-src/drivers/rk_nand/rk_nand_blk.c
echo "=== 4. cross gcc available for tool ==="
ls /vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/ | grep 'gcc$'
