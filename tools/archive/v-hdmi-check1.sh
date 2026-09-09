#!/bin/bash
# v-hdmi-check1.sh — HDMI regression audit for shipping kernel #26 (v24.4c)
echo '=== 1. V18HPD poll patch in kernel SOURCE ==='
grep -n 'V18HPD\|connector.polled' /vol/kernel-src/drivers/gpu/drm/rockchip/inno_hdmi.c

echo
echo '=== 2. DRM-related config (kernel-build .config) ==='
grep -E '^CONFIG_DRM|^CONFIG_FB=|^CONFIG_LIMA|^CONFIG_PANEL|^CONFIG_BACKLIGHT' /vol/kernel-build/.config | head -40

echo
echo '=== 3. kernel release string ==='
make -s -C /vol/kernel-src O=/vol/kernel-build kernelrelease 2>/dev/null

echo
echo '=== 4. inno_hdmi build artifacts (timestamps) ==='
ls -la --time-style=long-iso /vol/kernel-build/drivers/gpu/drm/rockchip/ 2>/dev/null | head -20

echo
echo '=== 5. dwmac patch backups present (v24.4 chain intact?) ==='
ls -la --time-style=long-iso /vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c* 2>/dev/null

echo
echo '=== 6. rootfs v23.2 source: modules dir ==='
ls /workspace/work/vmrootfs/lib/modules/ 2>/dev/null
ls /workspace/work/vmrootfs/lib/modules/*/kernel/drivers/gpu/drm/ 2>/dev/null | head -20
