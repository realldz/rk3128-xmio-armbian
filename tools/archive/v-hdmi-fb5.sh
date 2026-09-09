#!/bin/bash
# v-hdmi-fb5.sh — 6.6 fbmem internals: /proc/fb, unregister prints, who prints "frame buffer device"
echo '=== fbmem.c exists? ==='
ls -la /vol/kernel-src/drivers/video/fbdev/core/fbmem.c

echo
echo '=== /proc/fb creation ==='
grep -n 'proc_create\|fb_proc_fops\|proc_remove\|remove_proc_entry' /vol/kernel-src/drivers/video/fbdev/core/fbmem.c

echo
echo '=== unregister_framebuffer + any prints around it ==='
grep -n -A30 'int unregister_framebuffer' /vol/kernel-src/drivers/video/fbdev/core/fbmem.c | head -45

echo
echo '=== who prints "frame buffer device" ==='
grep -rn '" frame buffer device' /vol/kernel-src/drivers/ | head -5

echo
echo '=== CONFIG_FB=y exact ==='
grep -E '^CONFIG_FB=|^CONFIG_FB ' /vol/kernel-build/.config

echo
echo '=== fbmem init path ==='
grep -n -B3 -A20 '__init fbmem_init' /vol/kernel-src/drivers/video/fbdev/core/fbmem.c | head -40
