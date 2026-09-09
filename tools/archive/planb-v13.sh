#!/usr/bin/env bash
# planb-v13.sh — Plan B v13: single-timer SMP tick race fix (PERIODIC tick,
# no oneshot reprogram) + V13DIAG heartbeat + fine-grained initramfs diag.
# Runs INSIDE docker rk3128-build:  bash /workspace/tools/planb-v13.sh
# Only boot.img changes (kernel + initramfs). Flash boot.img -> 0xE000.
set -euo pipefail

SRC=/vol/kernel-src
B=/vol/kernel-build
OUT=/workspace/output/planb-stock-uboot
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 0. config: HZ_PERIODIC / no NO_HZ / no HIGH_RES ==="
cd "$SRC"
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
scripts/config --file "$B/.config" \
  --enable HZ_PERIODIC --disable NO_HZ_IDLE --disable NO_HZ_FULL \
  --disable NO_HZ --disable HIGH_RES_TIMERS
# re-refresh to drop stale NO_HZ_IDLE choice entry, then rebuild
make O="$B" olddefconfig > /workspace/work/v13-olddefconfig.log 2>&1
grep -E '^CONFIG_(HZ_PERIODIC|NO_HZ|NO_HZ_IDLE|NO_HZ_COMMON|HIGH_RES_TIMERS)=' \
  "$B/.config" || true

echo "=== 1. apply v13 kernel patch (on top of v12) ==="
python3 /workspace/tools/v13-patch.py "$SRC" | tee /workspace/work/v13-patch.log

echo "=== 2. kernel rebuild (timers+clocksource big change -> full make) ==="
make -j"$(nproc)" O="$B" zImage > /workspace/work/v13-build.log 2>&1 || {
  tail -40 /workspace/work/v13-build.log; exit 1; }
tail -4 /workspace/work/v13-build.log

echo "=== 2b. verify in vmlinux ==="
for s in "V13DIAG: hb jiffies" "V13DIAG: set_next_event cycles" \
         "V11DIAG: rknand probe enter" "V12DIAG: rq start"; do
  if strings "$B/vmlinux" | grep "$s" > /dev/null; then
    echo "DIAG OK: $s"
  else
    echo "FATAL: missing '$s'"; exit 1
  fi
done

echo "=== 3. patch initramfs ==="
cp -f "$B/arch/arm/boot/zImage" /workspace/output/kernel/zImage
ls -la /workspace/output/kernel/zImage
bash /workspace/tools/v13-initramfs.sh 2>&1 | tee /workspace/work/v13-initramfs.log
tail -3 /workspace/work/v13-initramfs.log

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
echo PLANB_V13_DONE
