#!/bin/bash
set -uo pipefail
CFG=/vol/uboot-build/.config
echo "=== feature check in final .config ==="
for k in RKNAND RKPARM_PARTITION VENDOR_PARTITION ADC_KEY GPIO_KEY DM_KEY RK_KEY CMD_BOOT_ROCKCHIP CMD_BOOT_ANDROID USING_KERNEL_DTB DEBUG_UART_BASE OPTEE_CLIENT CMD_FASTBOOT FASTBOOT_FLASH USB_GADGET_DOWNLOAD CMD_MMC MMC_DW_ROCKCHIP ANDROID_BOOTLOADER; do
  grep -E "^CONFIG_${k}=" "$CFG" || grep -E "^# CONFIG_${k} " "$CFG" || echo "CONFIG_${k}: ABSENT"
done
echo "=== vendor MAC read in board code ==="
grep -rn "LAN_MAC_ID\|vendor_storage\|rk_vendor_read" /vol/uboot-src/board/rockchip/common/board.c /vol/uboot-src/board/rockchip/rk3128/*.c 2>/dev/null | head -8
echo "=== strings in built binary ==="
for s in "vendor storage" "LAN_MAC" "bootrkp" "RKPARM" "rknand"; do
  printf '%-18s: ' "$s"; grep -ac "$s" /vol/uboot-build/u-boot.bin 2>/dev/null || echo 0
done
echo "=== size diff vs A26 payload ==="
ls -l /vol/uboot-build/u-boot.bin /vol/uboot-build/unpack-a26/uboot-a26.bin
