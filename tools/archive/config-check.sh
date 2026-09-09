#!/usr/bin/env bash
KC=/workspace/output/kernel/kernel.config
echo "=== rknand ==="
grep -E '^CONFIG_ROCKCHIP_RKNAND|^CONFIG_RKNAND' "$KC" || echo "CONFIG_ROCKCHIP_RKNAND not set (builtin=n or absent)"
echo "=== critical drivers (y=builtin, m=module) ==="
grep -E '^CONFIG_SND_SOC=|^CONFIG_DRM_ROCKCHIP|^CONFIG_USB_DWC2=|^CONFIG_USB_EHCI_HCD=|^CONFIG_USB_OHCI_HCD=|^CONFIG_MMC_DW_ROCKCHIP|^CONFIG_PWM_ROCKCHIP|^CONFIG_STMMAC_ETH|^CONFIG_STMMAC_PLATFORM|^CONFIG_DWMAC_ROCKCHIP|^CONFIG_PWM_ROCKCHIP_ONESHOT' "$KC" || true
echo "=== rknand module file? ==="
ls /workspace/output/kernel/ 2>/dev/null
echo CONFIGCHECK_DONE
