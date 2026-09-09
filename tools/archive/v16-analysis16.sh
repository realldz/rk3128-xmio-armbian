#!/usr/bin/env bash
exec > /workspace/work/v16-analysis16.log 2>&1
V=/workspace/work/xmio-planb-v9.dts
echo '=== all regulator-name in v9 dts ==='
grep -n 'regulator-name' $V
echo
echo '=== v9 pmic regulators block ==='
sed -n '1285,1420p' $V
echo
echo '=== v9: phandle of gpio1 bank (cd-gpios target) ==='
sed -n '1666,1690p' $V
