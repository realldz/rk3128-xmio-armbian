#!/usr/bin/env bash
exec > /workspace/work/v10-analysis4.log 2>&1
K=/vol/kernel-src
W=/workspace/work

echo "===== xmio-planb-v8.dts: cpus + smp-sram + psci ====="
grep -n "cpus\|cpu@\|enable-method\|smp-sram\|rk3066-smp-sram\|psci\|resets\|arm,armv7-timer\|timer@" $W/xmio-planb-v8.dts | head -60

echo "----- cpus block verbatim -----"
awk '/^\tcpus \{/,/^\t\};/' $W/xmio-planb-v8.dts

echo "----- smp-sram node verbatim -----"
grep -n -A8 "smp-sram" $W/xmio-planb-v8.dts

echo "===== gem_get_ddr_info body ====="
sed -n '/void rockchip_gem_get_ddr_info/,/^}/p' $K/drivers/gpu/drm/rockchip/rockchip_drm_gem.c

echo "===== dram_addrmap_info struct + bank_bit_first usage ====="
grep -rn "struct dram_addrmap_info" $K/include/ | head -3
grep -n -A10 "struct dram_addrmap_info {" $K/include/soc/rockchip/rockchip_sip.h 2>/dev/null || grep -rn -A10 "struct dram_addrmap_info {" $K/include/

echo "===== arm_smccc_smc impl on ARM32 no-firmware ====="
grep -rn "arm_smccc_smc" $K/include/linux/arm-smccc.h | head -5
grep -n "SMCCC_CONDUIT\|smccc_conduit" $K/arch/arm/kernel/smccc-call.S 2>/dev/null | head
ls $K/arch/arm/kernel/smccc* 2>/dev/null

echo "===== v9 diag current state files (verify volume tree intact) ====="
ls -la $K/include/linux/v9diag.h $K/drivers/tty/serial/8250/8250_dw.c $K/arch/arm/mach-rockchip/platsmp.c 2>&1 | head
grep -c "V9DIAG" $K/drivers/tty/serial/8250/8250_dw.c $K/drivers/tty/serial/8250/8250_port.c 2>/dev/null
echo V10_ANALYSIS4_DONE
