#!/usr/bin/env python3
# v24.2-dts.py — thêm node cpuinfo vào DTB source v23 (idempotent):
#   cpuinfo { compatible = "rockchip,cpuinfo"; nvmem-cells = <&cell-id@7>; }
# Phải chèn SAU efuse node để phandle của id@7 đã tồn tại trong file
# (dtc resolve forward refs được, nhưng in-place sau efuse là an toàn nhất).
import re, sys

P = '/workspace/work/xmio-planb-v23.dts'
src = open(P).read()

if 'rockchip,cpuinfo' in src:
    print('already present (idempotent)')
    sys.exit(0)

# tìm phandle của cell id@7 trong efuse node
m = re.search(r'efuse@20090000 \{.*?\n\t\};', src, re.S)
if not m:
    sys.exit('efuse node not found - abort')
blk = m.group(0)
pm = re.search(r'id@7 \{\s*reg = <0x0?7 0x10>;\s*phandle = <(0x[0-9a-f]+)>;', blk)
if not pm:
    sys.exit('id@7 phandle not found - abort')
ph = pm.group(1)
print(f'efuse id@7 phandle = {ph}')

NODE = f'''
\tcpuinfo {{
\t\tcompatible = "rockchip,cpuinfo";
\t\tnvmem-cells = <{ph}>;
\t\tnvmem-cell-names = "id";
\t}};
'''
src = src.replace(blk, blk + NODE, 1)
open(P, 'w').write(src)
print('cpuinfo node inserted after efuse')
