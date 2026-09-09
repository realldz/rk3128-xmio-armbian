#!/bin/bash
# v-hdmi-fb3.sh — who can unregister fb at runtime in 6.6 core
echo '=== unregister_info callers in core ==='
grep -rn 'drm_fb_helper_unregister_info\|unregister_framebuffer' /vol/kernel-src/drivers/gpu/drm/drm_fb_helper.c /vol/kernel-src/drivers/gpu/drm/drm_client.c /vol/kernel-src/drivers/gpu/drm/drm_client_event.c 2>/dev/null | head -20

echo
echo '=== rockchip drv context around fbdev init/fini (1850-1910) ==='
sed -n '1850,1910p' /vol/kernel-src/drivers/gpu/drm/rockchip/rockchip_drm_drv.c

echo
echo '=== lastclose / client handling in rockchip drv ==='
grep -n 'lastclose\|fbdev_helper\|fbdev_helper_restore' /vol/kernel-src/drivers/gpu/drm/rockchip/rockchip_drm_drv.c | head

echo
echo '=== any fbcon unbind in 6.6 core that drops fb ==='
grep -rn 'fb_notifier_call_chain\|FB_EVENT_FB_UNBIND' /vol/kernel-src/drivers/video/fbdev/core/fbcon.c | head -10
