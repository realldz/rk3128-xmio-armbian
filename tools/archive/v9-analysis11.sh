#!/usr/bin/env bash
exec > /workspace/work/v9-analysis11.log 2>&1
K=/vol/kernel-src

echo "===== uart_configure_port full body ====="
F=$K/drivers/tty/serial/serial_core.c
L=$(grep -n "uart_configure_port" $F | head -4)
echo "$L"
L2=$(grep -n "^static void uart_configure_port\|^static int uart_configure_port" $F | head -1 | cut -d: -f1)
E=$(awk -v s=$L2 'NR>=s && /^}/ {print NR; exit}' $F)
sed -n "${L2},${E}p" $F

echo "===== dw8250_do_pm ====="
F2=$K/drivers/tty/serial/8250/8250_dw.c
L3=$(grep -n "dw8250_do_pm" $F2 | head -3)
echo "$L3"
L4=$(grep -n "static void dw8250_do_pm" $F2 | cut -d: -f1)
E2=$(awk -v s=$L4 'NR>=s && /^}/ {print NR; exit}' $F2)
sed -n "${L4},${E2}p" $F2

echo "===== 8250_core.c head 30-70 ====="
sed -n '30,70p' $K/drivers/tty/serial/8250/8250_core.c

echo "===== serial_core.c head 30-60 ====="
sed -n '30,60p' $K/drivers/tty/serial/serial_core.c

echo "===== kernel config flags ====="
grep -E "CONFIG_ROCKCHIP_TIMER|CONFIG_ARM_ARCH_TIMER|CONFIG_CLKSRC_MMIO|CONFIG_SCHED_CLOCK|CONFIG_HAVE_ARM_ARCH_TIMER|CONFIG_NOP_TRXAGER|CONFIG_CALIBRATE" /vol/kernel-build/.config

echo "===== CRU gate macro ====="
grep -n "RK2928_CLKGATE_CON" $K/drivers/clk/rockchip/clk.h

echo "===== v8 dts aliases + timer node ====="
grep -n "timer@\|aliases" /workspace/work/xmio-planb-v8.dts | head

echo "===== user boot log lines in NOTES? ====="
ls /workspace/*.md /workspace/docs/ 2>/dev/null
echo V9_ANALYSIS11_DONE
