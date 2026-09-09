#!/usr/bin/env bash
# planb-v11.sh — Plan B v11: V11DIAG on the rk_nand init chain + rootdelay=60.
# Runs INSIDE docker rk3128-build:  bash /workspace/tools/planb-v11.sh
# Kernel + parameter.txt change. Root device hang diagnosis:
#   probe enter -> idb magic -> probe done -> nandc0 -> ftl init -> parts.
set -euo pipefail

SRC=/vol/kernel-src
B=/vol/kernel-build
OUT=/workspace/output/planb-stock-uboot
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. apply v11 patches (on top of v10) ==="
python3 /workspace/tools/v11-patch.py "$SRC" | tee /workspace/work/v11-patch.log

echo "=== 2. incremental zImage build ==="
cd "$SRC"
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make -j"$(nproc)" O="$B" zImage > /workspace/work/v11-build.log 2>&1 || {
  tail -40 /workspace/work/v11-build.log; exit 1; }
tail -4 /workspace/work/v11-build.log

echo "=== 2b. verify V11DIAG strings + rknand symbols in vmlinux ==="
# NOTE: no `grep -q` under pipefail — SIGPIPE makes a match look like failure.
if strings "$B/vmlinux" | grep "V11DIAG: rknand probe enter" > /dev/null; then
  echo "DIAG1 OK: probe-enter print linked"
else
  echo "FATAL: probe-enter string missing"; exit 1
fi
if strings "$B/vmlinux" | grep "V11DIAG: idb magic" > /dev/null; then
  echo "DIAG2 OK: idb-magic print linked"
else
  echo "FATAL: idb-magic string missing"; exit 1
fi
if strings "$B/vmlinux" | grep "V11DIAG: nandc0 NULL" > /dev/null; then
  echo "DIAG3 OK: silent-exit now loud"
else
  echo "FATAL: nandc0-NULL string missing"; exit 1
fi
if strings "$B/vmlinux" | grep "V11DIAG: nand_blk_register ok parts" > /dev/null; then
  echo "DIAG4 OK: parts print linked"
else
  echo "FATAL: parts string missing"; exit 1
fi
if nm "$B/vmlinux" | grep "rk_ftl_init" > /dev/null; then
  echo "FTL OK: rk_ftl_init still linked"
else
  echo "FATAL: rk_ftl_init missing"; exit 1
fi

cp -f "$B/arch/arm/boot/zImage" /workspace/output/kernel/zImage
ls -la "$B/arch/arm/boot/zImage"

echo "=== 3. repack boot.img (kernel only) ==="
mkbootimg --kernel /workspace/output/kernel/zImage \
  --ramdisk "$OUT/initrd.img.gz" \
  --second "$OUT/resource.img" \
  --base 0x60000000 --kernel_offset 0x00408000 \
  --ramdisk_offset 0x02000000 --second_offset 0x00F00000 \
  --tags_offset 0x00088000 --pagesize 16384 \
  --cmdline "" --output "$OUT/boot.img"

echo "=== 4. layout assert ==="
python3 - <<'EOF'
import struct
d = open('/workspace/output/planb-stock-uboot/boot.img','rb').read()
f = struct.unpack_from('<8s10I', d, 0)
k0,k1,r0,r1,s0,s1 = f[2],f[2]+f[1],f[4],f[4]+f[3],f[6],f[6]+f[5]
def ov(a0,a1,b0,b1): return max(a0,b0)<min(a1,b1)
assert not ov(k0,k1,s0,s1) and not ov(k0,k1,r0,r1) and not ov(r0,r1,s0,s1)
print('kernel %d | ramdisk %d | second %d @ %#x | RAM LAYOUT OK' % (f[1],f[3],f[5],f[6]))
EOF

echo "=== 5. hashes + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt uboot-stock.img misc.img baseparamer-720P.img \
  resource.img resource-baseline.img boot.img rk3128-xmio-planb.dtb \
  "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
echo PLANB_V11_DONE
