#!/usr/bin/env bash
exec > /workspace/work/v8-analysis4.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox
SC=$K/drivers/tty/serial/serial_core.c
P8=$K/drivers/tty/serial/8250/8250_port.c

echo "===== all uart_report_port / uart_add_one_port / register8250 defs ====="
grep -n "uart_report_port\|uart_add_one_port\|serial8250_register_8250_port" $SC | head
grep -n "uart_report_port\|uart_add_one_port\|serial8250_register_8250_port" $P8 | head

echo "===== uart_configure_port (2607..2700) ====="
sed -n '2607,2700p' $SC
echo V8_ANALYSIS4_DONE
