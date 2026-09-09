#!/usr/bin/env bash
echo "=== dev macro definitions in include/ ==="
grep -rn "define dev_err\|define dev_dbg\|define dev_info\|define dev_warn" /vol/uboot-sb/include | head -5
echo "=== dev_* used by scmi files ==="
grep -ohE 'dev_[a-z_]+\(' /vol/uboot-sb/drivers/firmware/scmi/*.c | sort -u
echo "=== dm/device.h has dev_err? ==="
grep -c 'dev_err' /vol/uboot-sb/include/dm/device.h
echo "=== config: SCMI + SDL ==="
grep -E 'SCMI|SDL' /vol/uboot-sb-build/.config
echo "=== sandbox cpu Makefile obj lines ==="
grep -n 'obj-' /vol/uboot-sb/arch/sandbox/cpu/Makefile
