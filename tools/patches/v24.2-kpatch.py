#!/usr/bin/env python3
# v24.2-kpatch.py — 2 patch kernel nhỏ cho /proc/cpuinfo:
# 1. rockchip.c: thêm "rockchip,rk3128" vào dt_compat
#    → Hardware: Rockchip (Device Tree) thay vì Generic DT based system
# 2. rockchip-cpuinfo.c: sau khi tính crc32 chip-ID, ghi đè chuỗi
#    system_serial (setup.c kasprintf sớm hơn khi crc32 = 0)
import shutil, sys

def patch(path, old, new, bak, tag):
    src = open(path).read()
    if new in src:
        print(f'{tag}: already patched (idempotent)')
        return
    if old not in src:
        sys.exit(f'{tag}: anchor not found in {path} - abort')
    shutil.copy(path, path + bak)
    open(path, 'w').write(src.replace(old, new, 1))
    print(f'{tag}: patched')

# 1. dt_compat (anchor: dòng rk2928 — duy nhất trong file)
patch('/vol/kernel-src/arch/arm/mach-rockchip/rockchip.c',
      '"rockchip,rk2928",',
      '"rockchip,rk3128",\n\t"rockchip,rk2928",',
      '.orig-v24.2', 'dt_compat-rk3128')

# 2. system_serial string
patch('/vol/kernel-src/drivers/soc/rockchip/rockchip-cpuinfo.c',
      '\tsystem_serial_high = crc32(system_serial_low, buf + 8, 8);\n',
      '\tsystem_serial_high = crc32(system_serial_low, buf + 8, 8);\n'
      '\t/* setup.c kasprintfs the string BEFORE this driver probes -\n'
      '\t * overwrite it now that the real per-device crc32s exist */\n'
      '\tsystem_serial = kasprintf(GFP_KERNEL, "%08x%08x",\n'
      '\t\t\t\t  system_serial_high, system_serial_low);\n',
      '.orig-v24.2', 'serial-string')
