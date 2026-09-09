#!/usr/bin/env bash
exec > /workspace/work/planb-build.log 2>&1
set -e
W=/workspace/work
S=$W/stock-rkunpack/Image
OUT=/workspace/output/planb-stock-uboot
mkdir -p "$OUT"

echo "=== stock boot.img header fields ==="
python3 - <<'EOF'
import struct
d = open('/workspace/work/stock-rkunpack/Image/boot.img','rb').read()
f = struct.unpack_from('<8s10I', d, 0)
names = ['magic','kernel_size','kernel_addr','ramdisk_size','ramdisk_addr',
         'second_size','second_addr','tags_addr','page_size','dt_size','dt_addr']
for n,v in zip(names,f):
    print(f'{n}: {v:#x}' if n!='magic' else f'{n}: {v}')
EOF

echo "=== 1. raw ramdisk from uInitrd (strip 64B mkimage header) ==="
mkdir -p /mnt/n
L=$(losetup --find --show /workspace/output/armbian_rootfs_26.2_xmio.img)
mount -o ro "$L" /mnt/n
tail -c +65 /mnt/n/boot/uInitrd-6.6.89-rk3128+ > "$OUT/initrd.img.gz"
umount /mnt/n; losetup -d "$L"
file "$OUT/initrd.img.gz"

echo "=== 2. resource images (our DTBs as rk-kernel.dtb) ==="
python3 /workspace/tools/pack_resource.py "$OUT/resource.img" \
  "path=/workspace/output/dtb/rk3128-xmio.dtb,name=rk-kernel.dtb"
python3 /workspace/tools/pack_resource.py "$OUT/resource-baseline.img" \
  "path=/workspace/output/dtb/rk3128-linux.dtb,name=rk-kernel.dtb"
python3 /workspace/tools/pack_resource.py --unpack "$OUT/resource.img" | head -4

echo "=== 3. boot.img via mkbootimg (stock addresses) ==="
mkbootimg --kernel /workspace/output/kernel/zImage \
  --ramdisk "$OUT/initrd.img.gz" \
  --second "$OUT/resource.img" \
  --base 0x60000000 --kernel_offset 0x00408000 \
  --ramdisk_offset 0x02000000 --second_offset 0x00C08000 \
  --tags_offset 0x00088000 --pagesize 16384 \
  --cmdline "" --output "$OUT/boot.img" 2>&1 || true
ls -la "$OUT/boot.img" 2>/dev/null || echo "mkbootimg failed, retry with stock-identical flags"

echo "=== 4. verify our boot.img header ==="
python3 - <<'EOF'
import struct
d = open('/workspace/output/planb-stock-uboot/boot.img','rb').read()
f = struct.unpack_from('<8s10I', d, 0)
print('magic:', f[0])
print('kernel_size: %d, kernel_addr: %#x' % (f[1], f[2]))
print('ramdisk_size: %d, ramdisk_addr: %#x' % (f[3], f[4]))
print('second_size: %d, second_addr: %#x' % (f[5], f[6]))
print('page_size: %d' % f[8])
EOF

echo "=== 5. parameter-xmio.txt ==="
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
CMDLINE:console=ttyS2,115200 console=ttyS1,115200 console=tty1 coherent_pool=2M initrd=0x62000000,0x00580000 root=/dev/rknand_root rootwait rw rootfstype=ext4 mtdparts=rk29xxnand:0x00002000@0x00002000(uboot),0x00002000@0x00004000(misc),0x00000800@0x00006000(baseparamer),0x00007800@0x00006800(resource),0x00009000@0x0000E000(boot),-@0x00017000(root)
PARR
cp "$S/misc.img" "$OUT/misc.img" 2>/dev/null || true
cp "$S/baseparamer-720P.img" "$OUT/baseparamer-720P.img" 2>/dev/null || true
cp /workspace/work/stock-rkunpack/uboot.img "$OUT/uboot-stock.img"
cp /workspace/work/stock-rkunpack/"rk3128MiniLoaderAll(L)_V2.25_ink.bin" "$OUT/" 2>/dev/null || cp "$S/../rk3128MiniLoaderAll(L)_V2.25_ink.bin" "$OUT/" 2>/dev/null || true
ls -la "$OUT"
echo PLANB_BUILD_DONE
