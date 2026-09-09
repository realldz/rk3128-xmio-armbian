#!/usr/bin/env bash
exec > /workspace/work/v8-analysis2.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox
SC=$K/drivers/tty/serial/serial_core.c
P8=$K/drivers/tty/serial/8250/8250_port.c
DW=$K/drivers/tty/serial/8250/8250_dw.c

echo "===== locate ====="
grep -n "^int uart_add_one_port\|^static void uart_report_port\|^static void uart_configure_port" $SC
grep -n "serial8250_register_8250_port\|univ8250_console" $P8 | head
grep -rn "univ8250_console_init" $K/drivers/tty/serial/8250/ | head

echo "===== serial_core.c: uart_report_port ====="
sed -n "$(grep -n 'static void uart_report_port' $SC | cut -d: -f1),+40p" $SC

echo "===== serial_core.c: uart_configure_port ====="
L=$(grep -n 'static void uart_configure_port' $SC | cut -d: -f1)
sed -n "${L},$((L+90))p" $SC

echo "===== serial_core.c: uart_add_one_port ====="
L=$(grep -n '^int uart_add_one_port' $SC | cut -d: -f1)
sed -n "${L},$((L+110))p" $SC

echo "===== 8250_port.c: serial8250_register_8250_port ====="
L=$(grep -n '^int serial8250_register_8250_port' $P8 | cut -d: -f1)
sed -n "${L},$((L+110))p" $P8

echo "===== 8250_dw.c: dw8250_do_pm (375-395) ====="
sed -n '375,395p' $DW

echo "===== 8250 console file location ====="
F=$(grep -rln "univ8250_console" $K/drivers/tty/serial/8250/ | head -1)
echo "console code file: $F"
if [ "$F" != "$P8" ]; then
  grep -n "console_setup\|console_write\|console_setup\|uart_set_options\|console_start\|CON_BOOT\|console_initcall" $F | head -25
fi
echo V8_ANALYSIS2_DONE
