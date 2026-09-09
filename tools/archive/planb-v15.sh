#!/usr/bin/env bash
# planb-v15.sh — v15 RELEASE: quiet console, zero periodic diag.
#   - strips all periodic instrumentation (v15-release.py), keeps every
#     functional fix (PERIODIC tick, clk gating off, keepon on, GC off,
#     arch-timer skip, SIP guard)
#   - parameter.txt: drop initcall_debug / ignore_loglevel / rootdelay=60
#     -> normal loglevel console, faster boot
#   - boot.img repacked from existing (proven) initramfs
# Flash AFTER this build: parameter.txt -> 0x0, boot.img -> 0xE000.
set -euo pipefail

SRC=/vol/kernel-src
B=/vol/kernel-build
OUT=/workspace/output/planb-stock-uboot
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. apply v15 release cleanup ==="
python3 /workspace/tools/v15-release.py "$SRC" | tee /workspace/work/v15-release-patch.log

echo "=== 2. kernel rebuild ==="
cd "$SRC"
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make -j"$(nproc)" O="$B" zImage > /workspace/work/v15-build.log 2>&1 || {
  tail -40 /workspace/work/v15-build.log; exit 1; }
tail -4 /workspace/work/v15-build.log

echo "=== 2b. verify: periodic diag GONE, boot one-shots kept ==="
for s in "V13HB" "V13DIAG: hb" "V12DIAG: rq" "V12DIAG: gc" \
         "V14CLK" "V14PDIAG" "V14DEAD" "V13DIAG: set_next_event"; do
  if strings "$B/vmlinux" | grep "$s" > /dev/null; then
    echo "FATAL: still present '$s'"; exit 1
  else
    echo "GONE OK: $s"
  fi
done
for s in "V9DIAG: rk_timer clkevt registered" "V11DIAG: rknand probe enter"; do
  if strings "$B/vmlinux" | grep "$s" > /dev/null; then
    echo "KEPT OK: $s"
  else
    echo "FATAL: missing boot one-shot '$s'"; exit 1
  fi
done

echo "=== 3. parameter.txt: quiet cmdline ==="
cp -f "$OUT/parameter.txt" "$OUT/parameter.txt.v14diag.bak"
sed -i 's/ initcall_debug / /; s/ ignore_loglevel / /; s/ rootdelay=60 / /' \
  "$OUT/parameter.txt"
grep '^CMDLINE:' "$OUT/parameter.txt" | head -c 400; echo

echo "=== 4. repack boot.img (proven v13 initramfs reused) ==="
cp -f "$B/arch/arm/boot/zImage" /workspace/output/kernel/zImage
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
  parameter.txt parameter.txt.v14diag.bak uboot-stock.img misc.img \
  baseparamer-720P.img resource.img resource-baseline.img boot.img \
  rk3128-xmio-planb.dtb "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
echo PLANB_V15_RELEASE_DONE
