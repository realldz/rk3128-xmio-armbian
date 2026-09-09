#!/bin/bash
# uboot-v3-facts.sh — dữ kiện để build v3: console UART2 + key hiệu chỉnh XMIO
set -uo pipefail
echo "############ 1. adc-keys XMIO (kernel DTS) ############"
sed -n '2278,2335p' /workspace/work/xmio-planb-v23.dts

echo
echo "############ 2. board_debug_uart_init cho rk3128 (dinh nghia o dau?) ############"
grep -rn "board_debug_uart_init" /vol/uboot-src/board/rockchip/evb_rk3128/ /vol/uboot-src/arch/arm/mach-rockchip/rk3128/ 2>/dev/null
F=/vol/uboot-src/board/rockchip/evb_rk3128/evb-rk3128.c
if grep -q "board_debug_uart_init" "$F" 2>/dev/null; then
  echo "--- noi dung ham trong $F:"
  grep -n -A30 "void board_debug_uart_init" "$F" | head -40
fi

echo
echo "############ 3. uart2 + saradc + chosen trong DTS nguon uboot (rk3128-evb.dts) ############"
grep -n -B2 -A8 "uart2\|saradc" /vol/uboot-src/arch/arm/dts/rk3128-evb.dts | head -50
grep -n -A3 "chosen" /vol/uboot-src/arch/arm/dts/rk3128-evb.dts

echo
echo "############ 4. code key: constants + ham doc ADC trong evb-rk3128.c ############"
grep -n "RK3128_MASKROM_ADC_CH\|RK3128_MASKROM_ADC_MAX\|RK3128_GPIO_WATCH\|gpio_key\|WATCH" "$F" | head -20
grep -n -A18 "rk3128_maskrom_key_pressed" "$F" | head -30
