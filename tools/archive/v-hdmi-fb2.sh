#!/bin/bash
# v-hdmi-fb2.sh — rockchip fbdev unregister paths
echo '=== rockchip_drm_fbdev.c structure ==='
grep -n 'rockchipdrmfb\|unregister\|fbdev_init\|fbdev_fini\|hotplug\|drm_fb_helper\|deferred\|static ' /vol/kernel-src/drivers/gpu/drm/rockchip/rockchip_drm_fbdev.c | head -40

echo
echo '=== who calls fbdev_fini / unregister ==='
grep -rn 'fbdev_fini\|fbdev_destroy\|rockchip_drm_fbdev' /vol/kernel-src/drivers/gpu/drm/rockchip/rockchip_drm_drv.c | head -20

echo
echo '=== connector hotplug in rockchip drv ==='
grep -n -B3 -A10 'hotplug' /vol/kernel-src/drivers/gpu/drm/rockchip/rockchip_drm_drv.c | head -50

echo
echo '=== inno_hdmi hpd / status change path ==='
grep -n -B2 -A8 'drm_helper_hpd_irq_event\|force_connectors\|status_change\|detect(' /vol/kernel-src/drivers/gpu/drm/rockchip/inno_hdmi.c | head -60
