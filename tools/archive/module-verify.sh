#!/usr/bin/env bash
exec > /workspace/work/module-verify.log 2>&1
set -e
mkdir -p /mnt/n
L=$(losetup --find --show /workspace/output/armbian_rootfs_26.2_xmio.img)
mount -o ro "$L" /mnt/n
echo "=== kernel release expected ==="
cat /workspace/output/kernel/kernel.release
echo "=== esp8089.ko vermagic ==="
modinfo -F vermagic /mnt/n/lib/modules/6.6.89-rk3128+/kernel/drivers/net/wireless/rockchip_wlan/rkwifi/esp8089/esp8089.ko
echo "=== all .ko vermagic unique values ==="
find /mnt/n/lib/modules/6.6.89-rk3128+ -name '*.ko' -o -name '*.ko.xz' -o -name '*.ko.zst' | head -50 | while read -r k; do
  modinfo -F vermagic "$k" 2>/dev/null
done | sort | uniq -c
echo "=== total .ko count ==="
find /mnt/n/lib/modules/6.6.89-rk3128+ -name '*.ko*' | wc -l
echo "=== depmod sanity: esp8089 resolvable? ==="
depmod -b /mnt/n 6.6.89-rk3128+ 2>&1 || true
grep -c esp8089 /mnt/n/lib/modules/6.6.89-rk3128+/modules.dep || echo "esp8089 NOT in modules.dep"
umount /mnt/n; losetup -d "$L"
echo "=== rknand built-in or module? ==="
KC=/workspace/output/kernel/kernel.config
grep -E '^CONFIG_ROCKCHIP_RKNAND|^CONFIG_RKNAND' "$KC" || echo "CONFIG_ROCKCHIP_RKNAND not set"
grep -E '^CONFIG_SND_SOC=|^CONFIG_DRM_ROCKCHIP|^CONFIG_USB_DWC2=|^CONFIG_USB_EHCI_HCD=|^CONFIG_USB_OHCI_HCD=|^CONFIG_MMC_DW_ROCKCHIP|^CONFIG_PWM_ROCKCHIP|^CONFIG_STMMAC_ETH|^CONFIG_STMMAC_PLATFORM|^CONFIG_DWMAC_ROCKCHIP' "$KC"
echo MODULE_VERIFY_DONE
