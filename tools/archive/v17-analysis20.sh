#!/usr/bin/env bash
exec > /workspace/work/v17-analysis20.log 2>&1
echo '=== UNDEFINED (C-side) symbols called by rk_ftlv5_arm32.o ==='
nm -u /vol/kernel-build/drivers/rk_nand/rk_ftlv5_arm32.o
echo
echo '=== UNDEFINED symbols of zftl_arm32.o (for contrast) ==='
nm -u /vol/kernel-build/drivers/rk_nand/rk_zftl_arm32.o | head -25
