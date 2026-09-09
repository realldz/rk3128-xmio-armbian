#!/usr/bin/env bash
# planb-v12.sh — Plan B v12: no background GC + V12DIAG + initramfs blkid skip.
# Runs INSIDE docker rk3128-build:  bash /workspace/tools/planb-v12.sh
# Only boot.img changes (kernel + initramfs). Flash boot.img -> 0xE000.
set -euo pipefail

SRC=/vol/kernel-src
B=/vol/kernel-build
OUT=/workspace/output/planb-stock-uboot
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. apply v12 kernel patch (on top of v11) ==="
python3 /workspace/tools/v12-patch.py "$SRC" | tee /workspace/work/v12-patch.log

echo "=== 2. incremental zImage build ==="
cd "$SRC"
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make -j"$(nproc)" O="$B" zImage > /workspace/work/v12-build.log 2>&1 || {
  tail -40 /workspace/work/v12-build.log; exit 1; }
tail -4 /workspace/work/v12-build.log

echo "=== 2b. verify in vmlinux ==="
if strings "$B/vmlinux" | grep "V12DIAG: rq start" > /dev/null; then
  echo "DIAG RQ OK"
else
  echo "FATAL: rq diag string missing"; exit 1
fi
if strings "$B/vmlinux" | grep "V12DIAG: gc enter" > /dev/null; then
  echo "DIAG GC OK"
else
  echo "FATAL: gc diag string missing"; exit 1
fi
if strings "$B/vmlinux" | grep "V11DIAG: rknand probe enter" > /dev/null; then
  echo "V11 DIAG STILL OK"
else
  echo "FATAL: v11 diag lost"; exit 1
fi

echo "=== 2c. sanity: probe read on the box disk (host-side) ==="
# nothing to do here; the initramfs does the probe read at boot

echo "=== 3. patch initramfs ==="
cp -f "$B/arch/arm/boot/zImage" /workspace/output/kernel/zImage
ls -la /workspace/output/kernel/zImage
bash /workspace/tools/v12-initramfs.sh 2>&1 | tee /workspace/work/v12-initramfs.log
tail -3 /workspace/work/v12-initramfs.log

echo "=== 4. repack boot.img ==="
mkbootimg --kernel /workspace/output/kernel/zImage \
  --ramdisk "$OUT/initrd.img.gz" \
  --second "$OUT/resource.img" \
  --base 0x60000000 --kernel_offset 0x00408000 \
  --ramdisk_offset 0x02000000 --second_offset 0x00F00000 \
  --tags_offset 0x00088000 --pagesize 16384 \
  --cmdline "" --output "$OUT/boot.img"

echo "=== 5. layout assert ==="
python3 - <<'EOF'
import struct
d = open('/workspace/output/planb-stock-uboot/boot.img','rb').read()
f = struct.unpack_from('<8s10I', d, 0)
k0,k1,r0,r1,s0,s1 = f[2],f[2]+f[1],f[4],f[4]+f[3],f[6],f[6]+f[5]
def ov(a0,a1,b0,b1): return max(a0,b0)<min(a1,b1)
assert not ov(k0,k1,s0,s1) and not ov(k0,k1,r0,r1) and not ov(r0,r1,s0,s1)
print('kernel %d | ramdisk %d | second %d @ %#x | RAM LAYOUT OK' % (f[1],f[3],f[5],f[6]))
EOF

echo "=== 6. hashes + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt uboot-stock.img misc.img baseparamer-720P.img \
  resource.img resource-baseline.img boot.img rk3128-xmio-planb.dtb \
  "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
echo PLANB_V12_DONE
