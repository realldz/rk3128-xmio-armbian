#!/usr/bin/env bash
exec > /workspace/work/sandbox-build.log 2>&1
set -e
cd /vol/uboot-sb
grep -q CONFIG_RSA_N_SIZE /vol/uboot-sb-build/.config || echo "CONFIG_RSA_N_SIZE=2048" >> /vol/uboot-sb-build/.config
grep -q CONFIG_RSA_C_SIZE /vol/uboot-sb-build/.config || echo "CONFIG_RSA_C_SIZE=2048" >> /vol/uboot-sb-build/.config
yes '' | make O=/vol/uboot-sb-build oldconfig
make -j8 O=/vol/uboot-sb-build
ls -la /vol/uboot-sb-build/u-boot
echo SANDBOX_BUILD_DONE
