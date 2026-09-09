#!/usr/bin/env bash
# v24.2-prep.sh — kiểm tra trước khi patch cpuinfo/machine
set -uo pipefail
cd /vol/kernel-src

echo "=== 1. efuse node trong DTB v23 (cells co san?) ==="
python3 - <<'EOF'
d = open('/workspace/work/xmio-planb-v23.dts').read()
i = d.find('efuse')
while i != -1:
    seg = d[i-200:i+1600]
    if 'efuse@20090000' in seg or 'rk3128-efuse' in seg:
        print(seg[:1800])
        break
    i = d.find('efuse', i+1)
else:
    print("KHONG TIM THAY efuse node!")
EOF

echo
echo "=== 2. rockchip-efuse.c: cells bang driver hay DT-con? ==="
grep -n 'cells\|clk_prepare_enable\|reg_read' drivers/nvmem/rockchip-efuse.c | head -20

echo
echo "=== 3. vendor dts co san node cpuinfo cho rk3128? ==="
grep -rn 'rockchip,cpuinfo' arch/arm/boot/dts/ | grep -i '3128\|rk32' | head -5
grep -rln 'rockchip,cpuinfo' arch/arm/boot/dts/ | head -8

echo
echo "=== 4. cpu.h: RK3128 soc id + rockchip_set_cpu ==="
grep -n 'RK3128' include/linux/rockchip/cpu.h | head -8
grep -n 'rockchip_set_cpu\b' include/linux/rockchip/cpu.h | head -3

echo
echo "=== 5. An toan machine: rockchip_timer_init + suspend_init ==="
sed -n '/static void __init rockchip_timer_init/,/^}/p' arch/arm/mach-rockchip/rockchip.c | head -30
grep -rn 'void rockchip_suspend_init' arch/arm/mach-rockchip/ | head -3

echo
echo "=== 6. CONFIG_NO_GKI hien trang ==="
grep -n 'CONFIG_NO_GKI' /vol/kernel-build/.config || echo "(khong set - chuon: serial bi gate)"