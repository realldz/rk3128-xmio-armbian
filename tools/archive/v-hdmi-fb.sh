#!/bin/bash
# v-hdmi-fb.sh — how does 6.6 drm fbdev destroy/restore fbcon fb on hotplug?
echo '=== drm_fb_helper hotplug path (6.6 in-tree) ==='
grep -n 'drm_fb_helper_hotplug_event\|release_fbi\|alloc_fbi\|drm_fb_helper_fb_probe\|delayed_hotplug\|unregister_fbi' /vol/kernel-src/drivers/gpu/drm/drm_fb_helper.c | head -30

echo
echo '=== generic client hotplug (drm_fbdev generic emulation) ==='
grep -n -B2 -A12 'drm_fbdev_client_hotplug' /vol/kernel-src/drivers/gpu/drm/drm_fbdev_dma.c 2>/dev/null | head -40
grep -rn 'drm_client_dev_hotplug\|client.hotplug' /vol/kernel-src/drivers/gpu/drm/drm_client.c | head -10

echo
echo '=== rockchip error_event monitor (what does it do?) ==='
grep -rn -B3 -A15 'error_event' /vol/kernel-src/drivers/gpu/drm/rockchip/*.c | head -60
