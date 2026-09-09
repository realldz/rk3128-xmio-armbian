#!/usr/bin/env bash
# Analyze the XMIO stock device tree
D="$1"
echo "===== compatible / model ====="
grep -n -m2 -E 'model|compatible' "$D" | head -5
echo "===== pwm regulators ====="
sed -n '/pwm-regulator1 {/,/};/p;/pwm-regulator2 {/,/};/p' "$D" | head -60
echo "===== hdmi / tve / vop / lcdc ====="
sed -n '/\bhdmi\b.*{/,/};/p' "$D" | head -40
sed -n '/tve@/,/};/p' "$D" | head -30
grep -n -E 'status' "$D" | grep -iE 'hdmi|tve|vop|lcd|rga' | head -20
echo "===== usb ====="
sed -n '/dwc-control-usb@20008000 {/,/};/p' "$D" | head -80
grep -n -E 'usb@|otg|ehci|ohci|usb_id|vbus' "$D" | head -40
echo "===== wireless-wlan ====="
sed -n '/wireless-wlan {/,/};/p' "$D"
echo "===== sdio / sdmmc / emmc ====="
sed -n '/&sdio {/,/};/p' "$D" | head -30
grep -n -E 'sdio|sdmmc|emmc|nandc' "$D" | head -40
echo "===== uart ====="
grep -n -E 'uart[0-9]' "$D" | head -20
echo "===== i2c regulators / pmic ====="
grep -n -E 'rk8|tps|pmic|vcc[0-9a-z_]*:' "$D" | head -30
echo "===== memory ====="
sed -n '/memory {/,/};/p' "$D"
echo "===== chosen ====="
sed -n '/chosen {/,/};/p' "$D"
