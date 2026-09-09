#!/usr/bin/env bash
exec > /workspace/work/sandbox-build2.log 2>&1
set -e
cd /vol/uboot-sb
sed -i '/CONFIG_RSA_N_SIZE/d;/CONFIG_RSA_C_SIZE/d' /vol/uboot-sb-build/.config
sed -i 's/^CONFIG_RSA_SOFTWARE_EXP=.*/# CONFIG_RSA_SOFTWARE_EXP is not set/' /vol/uboot-sb-build/.config
grep -q 'CONFIG_RSA_SOFTWARE_EXP' /vol/uboot-sb-build/.config || echo "# CONFIG_RSA_SOFTWARE_EXP is not set" >> /vol/uboot-sb-build/.config
make O=/vol/uboot-sb-build olddefconfig
make -j8 O=/vol/uboot-sb-build
ls -la /vol/uboot-sb-build/u-boot
echo SANDBOX_BUILD2_DONE
