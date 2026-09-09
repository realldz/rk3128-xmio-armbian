#!/usr/bin/env bash
exec > /workspace/work/v17-analysis21.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== all usleep_range call sites in ftlv5 blob + preceding arg loads ==='
grep -n 'usleep_range' rk_ftlv5_arm32.S
echo
for L in $(grep -n 'usleep_range' rk_ftlv5_arm32.S | cut -d: -f1); do
  S=$((L-8)); E=$((L+2))
  echo "--- context around line $L ---"
  sed -n "${S},${E}p" rk_ftlv5_arm32.S
done
echo
echo '=== arm_delay_ops usage (udelay path already?) ==='
grep -n 'arm_delay_ops' rk_ftlv5_arm32.S | head -8
