#!/bin/bash
# v-hdmi-fb4.sh — check boot-param tracer support and fbmem unregister prints
echo '=== kernel-parameters: ftrace / trace_options / dyndbg ==='
grep -nE '^.*(ftrace=|trace_options=|ftrace_filter=|ftrace_graph_filter=|dyndbg=|drm\.debug=)' /vol/kernel-src/Documentation/admin-guide/kernel-parameters.txt | head -20

echo
echo '=== unregister_framebuffer body: any pr_* prints? ==='
sed -n '/^void unregister_framebuffer/,/^}/p' /vol/kernel-src/drivers/video/fbdev/core/fbmem.c | head -60

echo
echo '=== fbmem: when is /proc/fb created? ==='
grep -n 'proc_create\|fb_proc' /vol/kernel-src/drivers/video/fbdev/core/fbmem.c | head

echo
echo '=== dynamic debug config ==='
grep -E 'CONFIG_DYNAMIC_DEBUG|CONFIG_DRM_DEBUG_SELFTEST' /vol/kernel-build/.config | head -5
