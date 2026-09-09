#!/usr/bin/env bash
exec > /workspace/work/v8-analysis5.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox
SC=$K/drivers/tty/serial/serial_core.c
C8=$K/drivers/tty/serial/8250/8250_core.c

echo "===== locate uart_add_one_port / register8250 / dw8250_setup_port ====="
grep -n "uart_add_one_port" $SC | head -8
grep -n "serial8250_register_8250_port" $C8 | head -8
grep -n "static void dw8250_setup_port" $K/drivers/tty/serial/8250/8250_dw.c

echo "===== uart_add_one_port body ====="
L=$(grep -n "uart_add_one_port(struct uart_driver" $SC | cut -d: -f1)
echo "def at line $L"
[ -n "$L" ] && sed -n "${L},$((L+130))p" $SC

echo "===== serial8250_register_8250_port body ====="
L=$(grep -n "serial8250_register_8250_port(struct uart_8250_port" $C8 | cut -d: -f1)
echo "def at line $L"
[ -n "$L" ] && sed -n "${L},$((L+130))p" $C8

echo "===== register_console: match() fallback semantics ====="
P=$(grep -rln "void register_console" $K/kernel/printk/ | head -1)
echo "register_console in $P"
L=$(grep -n "void register_console" $P | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "${L},$((L+120))p" $P
echo V8_ANALYSIS5_DONE
