#!/usr/bin/env bash
exec > /workspace/work/v8-analysis3.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox
SC=$K/drivers/tty/serial/serial_core.c
P8=$K/drivers/tty/serial/8250/8250_port.c

echo "===== locate (no anchor) ====="
grep -n "uart_add_one_port(struct uart_driver" $SC
grep -n "uart_report_port(struct uart_port" $SC
grep -n "uart_configure_port(struct uart_driver" $SC
grep -n "serial8250_register_8250_port(struct uart_8250_port" $P8

echo "===== uart_report_port ====="
L=$(grep -n "static void uart_report_port" $SC | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "${L},$((L+45))p" $SC

echo "===== uart_configure_port ====="
L=$(grep -n "static void uart_configure_port" $SC | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "${L},$((L+95))p" $SC

echo "===== uart_add_one_port ====="
L=$(grep -n "int uart_add_one_port" $SC | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "${L},$((L+120))p" $SC

echo "===== serial8250_register_8250_port ====="
L=$(grep -n "int serial8250_register_8250_port" $P8 | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "${L},$((L+120))p" $P8

echo "===== 8250_core.c univ8250_console_setup (605-700) ====="
sed -n '605,700p' $K/drivers/tty/serial/8250/8250_core.c
echo V8_ANALYSIS3_DONE
