#!/usr/bin/env bash
KC=/workspace/output/kernel/kernel.config
SRC=/workspace/repos/linux-kernel-6.6-rk3128-tvbox
echo "=== all NAND-ish configs in kernel.config ==="
grep -in 'nand' "$KC" | head -20
echo "=== rknand driver in source tree? ==="
grep -rln 'rknand' "$SRC/drivers" 2>/dev/null | head -10
echo "=== rknand_root string in source ==="
grep -rln 'rknand_root' "$SRC" 2>/dev/null | head -5
echo "=== mtd_blk / nand driver Kconfig ==="
grep -rn 'RKNAND\|RK_NAND' "$SRC/drivers/block/Kconfig" "$SRC/drivers/mtd/Kconfig" "$SRC/drivers/mtd/nand/ Kconfig" 2>/dev/null | head -10
echo RKNAND_PROBE_DONE
