#!/usr/bin/env bash
exec > /workspace/work/v9-analysis12.log 2>&1
K=/vol/kernel-src

echo "===== serial_core.c 2590-2690 ====="
sed -n '2590,2690p' $K/drivers/tty/serial/serial_core.c

echo "===== 8250_dw.c 370-400 ====="
sed -n '370,400p' $K/drivers/tty/serial/8250/8250_dw.c

echo "===== NOTES.md size + last section ====="
wc -l /workspace/NOTES.md
grep -n "^## " /workspace/NOTES.md | tail -5
echo V9_ANALYSIS12_DONE
