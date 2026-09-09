#!/usr/bin/env bash
exec > /workspace/work/v10-analysis7.log 2>&1
K=/vol/kernel-src
D=/workspace/work/xmio-planb-v8.dts

echo "===== dmc node in v8 dts ====="
grep -n "dmc" $D
echo "----- dmc node verbatim -----"
grep -n -A12 "dmc {" $D | head -30

echo "===== rk3066-pmu / rockchip,pmu in dts ====="
grep -n "rk3066-pmu\|rockchip,pmu" $D

echo "===== rockchip_dmc.c: functions containing direct smc (1730-1790) ====="
sed -n '1725,1795p' $K/drivers/devfreq/rockchip_dmc.c

echo "===== when are those called: grep callers ====="
grep -n "rockchip_dmc_set_read_latency\|rockchip_dmc_set_timing\|dmc_set_timing\|set_read_latency" $K/drivers/devfreq/rockchip_dmc.c | head -20

echo "===== rk3128_dmc_init body ====="
awk '/rk3128_dmc_init/,/^}/' $K/drivers/devfreq/rockchip_dmc.c | head -50

echo "===== rk_system_heap null-check ====="
sed -n '815,845p' $K/drivers/dma-buf/heaps/rk_system_heap.c

echo "===== rk3128 cru uses sip ddrclk? ====="
grep -n "rockchip_ddrclk" $K/drivers/clk/rockchip/clk-rk3128.c 2>/dev/null
grep -rn "rockchip_ddrclk_sip_get" $K/drivers/clk/rockchip/*.c | head
echo V10_ANALYSIS7_DONE
