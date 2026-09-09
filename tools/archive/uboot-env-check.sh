#!/usr/bin/env bash
exec > /workspace/work/uboot-env.log 2>&1
U=/workspace/A26-release-20260430/A26-release-20260430/uboot.img
echo "=== boot_targets default ==="
strings "$U" | grep -E '^boot_targets=' || echo '(no boot_targets string)'
echo "=== bootcmd variants ==="
strings "$U" | grep -E '^bootcmd' | head -10
echo "=== distro/android flow ==="
strings "$U" | grep -iE 'distro_bootcmd|boot_android|boot_rockchip' | head -8
echo "=== rknand / armbianEnv / boot.scr references ==="
strings "$U" | grep -iE 'rknand|armbianEnv|boot\.scr|boot\.cmd' | head -12
echo "=== bootdelay / prompt ==="
strings "$U" | grep -E 'bootdelay|RK3128 >>' | head -4
echo UBOOT_ENV_DONE
