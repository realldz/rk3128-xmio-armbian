#!/usr/bin/env bash
exec > /workspace/work/v18-analysis6.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== loop at line 2000: find r4 init (lines 1960-2010) ==='
sed -n '1960,2010p' rk_ftlv5_arm32.S
echo
echo '=== find what sets r4 before .L333 (search 1920-1960) ==='
sed -n '1920,1960p' rk_ftlv5_arm32.S | grep -n 'r4' 
echo
echo '=== timeout path after loop falls through (2010-2040) ==='
sed -n '2010,2045p' rk_ftlv5_arm32.S
