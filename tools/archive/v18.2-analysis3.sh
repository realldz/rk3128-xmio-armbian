#!/usr/bin/env bash
exec > /workspace/work/v18.2-analysis3.log 2>&1
echo '=== current accounting-related configs ==='
grep -E 'CONFIG_TASKSTATS|CONFIG_TASK_DELAY_ACCT|CONFIG_TASK_XACCT|CONFIG_TASK_IO_ACCOUNTING|CONFIG_IRQ_TIME_ACCOUNTING|CONFIG_BSD_PROCESS_ACCT' /vol/kernel-build/.config || echo '(none set)'
echo
echo '=== does /proc/pid/io require TASK_IO_ACCOUNTING? confirm kernel version ==='
grep 'CONFIG_IKCONFIG\|CONFIG_LOCALVERSION=' /vol/kernel-build/.config | head -2
