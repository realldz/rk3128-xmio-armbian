#!/usr/bin/env bash
exec > /workspace/work/v8-analysis.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox
echo "===== 8250_dw.c: dw8250_probe ====="
awk '/^static int dw8250_probe/,/^}/' $K/drivers/tty/serial/8250/8250_dw.c
echo "===== 8250_dw.c: runtime pm lines ====="
grep -n "pm_runtime\|autosuspend" $K/drivers/tty/serial/8250/8250_dw.c | head -30
echo "===== serial_core.c: uart_add_one_port ====="
awk '/^int uart_add_one_port/,/^}/' $K/drivers/tty/serial/serial_core.c
echo "===== serial_core.c: uart_report_port ====="
awk '/^static void uart_report_port/,/^}/' $K/drivers/tty/serial/serial_core.c
echo "===== serial_core.c: uart_configure_port ====="
awk '/^static void uart_configure_port/,/^}/' $K/drivers/tty/serial/serial_core.c
echo "===== 8250_port.c: univ8250_console_init + console struct ====="
awk '/static struct console univ8250_console/,/^};/' $K/drivers/tty/serial/8250/8250_port.c | head -40
awk '/^static int __init univ8250_console_init/,/^}/' $K/drivers/tty/serial/8250/8250_port.c
echo "===== 8250_port.c: serial8250_console_setup ====="
awk '/^static int serial8250_console_setup/,/^}/' $K/drivers/tty/serial/8250/8250_port.c
echo "===== 8250_port.c: univ8250 console match / port activation ====="
grep -n "univ8250_console_port\|console_start\|console_stop\|CON_ANYTIME\|match" $K/drivers/tty/serial/8250/8250_port.c | head -30
echo "===== 8250_port.c: serial8250_console_write rpm ====="
awk '/^static void serial8250_console_write/,/^}/' $K/drivers/tty/serial/8250/8250_port.c | head -60
echo "===== 8250_port.c: rpm helpers ====="
grep -n "serial8250_rpm_get\b\|static.*serial8250_rpm_get\|rpm_id" $K/drivers/tty/serial/8250/8250_port.c | head -20
echo "===== init/main.c: initcall debug print format ====="
grep -n "calling  \|@ %i\|raw_smp_processor_id\|returned %d after\|local_clock" $K/init/main.c | head -15
echo "===== main.c do_one_initcall timing ====="
awk '/^int do_one_initcall/,/^}/' $K/init/main.c | head -60
echo V8_ANALYSIS_DONE
