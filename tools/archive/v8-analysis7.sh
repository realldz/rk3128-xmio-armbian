#!/usr/bin/env bash
exec > /workspace/work/v8-analysis7.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox

echo "===== uart_add_one_port (serial_port.c:140+) ====="
sed -n '140,250p' $K/drivers/tty/serial/serial_port.c

echo "===== dw8250_setup_port body ====="
L=$(grep -n "static void dw8250_setup_port" $K/drivers/tty/serial/8250/8250_dw.c | cut -d: -f1)
sed -n "${L},$((L+55))p" $K/drivers/tty/serial/8250/8250_dw.c

echo "===== autoconfig: any udelay/mdelay? ====="
P8=$K/drivers/tty/serial/8250/8250_port.c
L=$(grep -n "static void autoconfig(" $P8 | cut -d: -f1)
echo "autoconfig at $L"
sed -n "${L},$((L+30))p" $P8
awk 'NR>=((start)-0) && NR<=(start+260)' start=$L $P8 | grep -n "udelay\|mdelay\|timeout" | head

echo "===== dw8250_clk_work_cb + notifier ====="
L=$(grep -n "dw8250_clk_work_cb" $K/drivers/tty/serial/8250/8250_dw.c | head -1 | cut -d: -f1)
sed -n "${L},$((L+30))p" $K/drivers/tty/serial/8250/8250_dw.c

echo "===== serial8250_console_setup body ====="
L=$(grep -n "static int serial8250_console_setup" $P8 | cut -d: -f1)
sed -n "${L},$((L+55))p" $P8

echo "===== uart_set_options ====="
L=$(grep -n "int uart_set_options" $K/drivers/tty/serial/serial_port.c | cut -d: -f1)
echo "uart_set_options at $L (serial_port.c)"
[ -n "$L" ] && sed -n "${L},$((L+80))p" $K/drivers/tty/serial/serial_port.c
grep -rn "int uart_set_options" $K/drivers/tty/serial/ | head -3

echo "===== try_enable_new_console / preferred semantics ====="
PK=$K/kernel/printk/printk.c
L=$(grep -n "static int try_enable_preferred_console" $PK | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "${L},$((L+70))p" $PK

echo "===== uart_report_port body ====="
SC=$K/drivers/tty/serial/serial_core.c
L=$(grep -n "uart_report_port(struct uart_driver" $SC | cut -d: -f1)
sed -n "${L},$((L+42))p" $SC
echo V8_ANALYSIS7_DONE
