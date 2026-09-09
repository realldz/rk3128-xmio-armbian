#!/usr/bin/env bash
exec > /workspace/work/planb-bootimg.log 2>&1
set -e
OUT=/workspace/output/planb-stock-uboot
mkbootimg --kernel /workspace/output/kernel/zImage \
  --ramdisk "$OUT/initrd.img.gz" \
  --second "$OUT/resource.img" \
  --base 0x60000000 --kernel_offset 0x00408000 \
  --ramdisk_offset 0x02000000 --second_offset 0x00F00000 \
  --tags_offset 0x00088000 --pagesize 16384 \
  --cmdline "" --output "$OUT/boot.img"
python3 - <<'EOF'
import struct
d = open('/workspace/output/planb-stock-uboot/boot.img','rb').read()
f = struct.unpack_from('<8s10I', d, 0)
print('magic:', f[0])
print('kernel_size: %d, kernel_addr: %#x' % (f[1], f[2]))
print('ramdisk_size: %d, ramdisk_addr: %#x' % (f[3], f[4]))
print('second_size: %d, second_addr: %#x' % (f[5], f[6]))
print('page_size: %d' % f[8])
# OVERLAP ASSERTIONS (all regions in load order: kernel, ramdisk, second)
k0, k1 = f[2], f[2]+f[1]
r0, r1 = f[4], f[4]+f[3]
s0, s1 = f[6], f[6]+f[5]
def ov(a0,a1,b0,b1): return max(a0,b0) < min(a1,b1)
assert not ov(k0,k1,s0,s1), f'second {s0:#x}-{s1:#x} overlaps kernel {k0:#x}-{k1:#x}'
assert not ov(k0,k1,r0,r1), 'ramdisk overlaps kernel'
assert not ov(r0,r1,s0,s1), 'second overlaps ramdisk'
print('RAM LAYOUT OK: kernel %#x-%#x  second %#x-%#x  ramdisk %#x-%#x' % (k0,k1,s0,s1,r0,r1))
# DTB magic present inside second area?
ps = f[8]
sa = ps * (1 + (f[1]+ps-1)//ps + (f[3]+ps-1)//ps)
print('second blob starts at file offset %d, magic: %s' % (sa, d[sa:sa+4]))
EOF
ls -la "$OUT"
echo PLANB_BOOTIMG_DONE
