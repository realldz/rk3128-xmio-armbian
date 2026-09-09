#!/usr/bin/env bash
# Plan B v3: fix the two kernel-side killers found by source analysis:
#  1) FDT-boot path passes NO ATAGs -> DTB must carry /memory (it had none)
#  2) DTB chosen/earlycon pointed at UART1 while the box console is elsewhere;
#     enable uart0+uart2, earlycon on 0x20060000 AND 0x20068000, all 3 ttys.
#  3) drop initrd= from parameter (its address 0x62000000 is where U-Boot
#     loads the KERNEL -> kernel would reserve+unpack garbage there).
exec > /workspace/work/planb-v3.log 2>&1
set -e
W=/workspace/work
OUT=/workspace/output/planb-stock-uboot

echo "=== 1. build v3 DTS from merged-nand.dts ==="
python3 - "$W/merged-nand.dts" "$W/xmio-planb.dts" <<'EOF'
import sys, re
src, dst = sys.argv[1], sys.argv[2]
t = open(src, encoding='utf-8').read()

# (a) chosen bootargs: all 3 uarts earlycon + consoles, verbose
t = t.replace(
  'bootargs = "earlycon=uart8250,mmio32,0x20064000 console=ttyS1,115200n8";',
  'bootargs = "earlycon=uart8250,mmio32,0x20060000 earlycon=uart8250,mmio32,0x20068000 '
  'console=ttyS0,115200 console=ttyS1,115200 console=ttyS2,115200 console=tty1 ignore_loglevel";')

# (b) stdout-path -> serial2 (uart2, where the user demonstrably sees U-Boot)
t = t.replace('stdout-path = "serial1:115200n8";', 'stdout-path = "serial2:115200n8";')

# (c) enable uart0 (stock fiq-debugger is serial-id 0 there)
m = re.search(r'(serial@20060000 \{.*?\n\t\};)', t, re.S)
assert m, 'uart0 node not found'
node = m.group(1)
node2 = node.replace('status = "disabled"', 'status = "okay"')
assert node2 != node, 'uart0 status not disabled?'
t = t.replace(node, node2)

# (d) add /memory node (U-Boot banner: 128 MiB @0x60000000) before chosen
assert 'device_type = "memory"' not in t
mem = ('\tmemory@60000000 {\n'
       '\t\tdevice_type = "memory";\n'
       '\t\treg = <0x60000000 0x08000000>;\n'
       '\t};\n\n')
idx = t.index('\tchosen {')
t = t[:idx] + mem + t[idx:]

open(dst, 'w', encoding='utf-8').write(t)
print('v3 DTS written:', dst)
EOF

echo "=== 2. compile v3 DTB + sanity ==="
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb.dts"
fdtdump -s "$OUT/rk3128-xmio-planb.dtb" | head -3
python3 - "$OUT/rk3128-xmio-planb.dtb" <<'EOF'
import sys, subprocess
d = subprocess.run(['dtc','-I','dtb','-O','dts',sys.argv[1]],capture_output=True,text=True).stdout
assert 'memory@60000000' in d, 'memory node missing'
assert 'device_type = "memory"' in d
assert 'reg = <0x60000000 0x8000000>' in d or 'reg = <0x60000000 0x08000000>' in d, 'memory reg wrong'
assert '0x20060000 0x20068000' in d or '0x20060000 earlycon' in d, 'earlycon missing'
assert 'earlycon=uart8250,mmio32,0x20060000' in d and 'earlycon=uart8250,mmio32,0x20068000' in d
assert 'stdout-path = "serial2:115200n8"' in d
# uart0 enabled
import re
m = re.search(r'serial@20060000 \{[^}]*status = "(.*?)"', d, re.S)
print('uart0 status:', m.group(1)); assert m.group(1)=='okay'
m2 = re.search(r'serial@20068000 \{[^}]*status = "(.*?)"', d, re.S)
print('uart2 status:', m2.group(1)); assert m2.group(1)=='okay'
print('DTS SANITY OK')
EOF

echo "=== 3. parameter.txt v3 (no initrd=, earlycon both uarts) ==="
cat > "$OUT/parameter.txt" <<'PARR'
FIRMWARE_VER:6.6.89
MACHINE_MODEL:rk312x
MACHINE_ID:007
MANUFACTURER:RK30SDK
MAGIC: 0x5041524B
ATAG: 0x60000800
MACHINE: 312x
CHECK_MASK: 0x80
KERNEL_IMG: 0x60408000
CMDLINE:earlycon=uart8250,mmio32,0x20060000 earlycon=uart8250,mmio32,0x20068000 console=ttyS0,115200 console=ttyS1,115200 console=ttyS2,115200 console=tty1 ignore_loglevel coherent_pool=2M root=/dev/rknand_root rootwait rw rootfstype=ext4 mtdparts=rk29xxnand:0x00002000@0x00002000(uboot),0x00002000@0x00004000(misc),0x00000800@0x00006000(baseparamer),0x00007800@0x00006800(resource),0x00009000@0x0000E000(boot),-@0x00017000(root)
PARR

echo "=== 4. resource.img with v3 DTB + rebuild boot.img ==="
python3 /workspace/tools/pack_resource.py "$OUT/resource.img" \
  "path=$OUT/rk3128-xmio-planb.dtb,name=rk-kernel.dtb"
mkbootimg --kernel /workspace/output/kernel/zImage \
  --ramdisk "$OUT/initrd.img.gz" \
  --second "$OUT/resource.img" \
  --base 0x60000000 --kernel_offset 0x00408000 \
  --ramdisk_offset 0x02000000 --second_offset 0x00F00000 \
  --tags_offset 0x00088000 --pagesize 16384 \
  --cmdline "" --output "$OUT/boot.img"

echo "=== 5. verify boot.img + hashes ==="
python3 - <<'EOF'
import struct
d = open('/workspace/output/planb-stock-uboot/boot.img','rb').read()
f = struct.unpack_from('<8s10I', d, 0)
print('kernel %d @ %#x | ramdisk %d @ %#x | second %d @ %#x | page %d' %
      (f[1],f[2],f[3],f[4],f[5],f[6],f[8]))
k0,k1,r0,r1,s0,s1 = f[2],f[2]+f[1],f[4],f[4]+f[3],f[6],f[6]+f[5]
def ov(a0,a1,b0,b1): return max(a0,b0)<min(a1,b1)
assert not ov(k0,k1,s0,s1) and not ov(k0,k1,r0,r1) and not ov(r0,r1,s0,s1)
print('RAM LAYOUT OK')
EOF
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt uboot-stock.img misc.img baseparamer-720P.img \
  resource.img resource-baseline.img boot.img rk3128-xmio-planb.dtb \
  "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
echo PLANB_V3_DONE
