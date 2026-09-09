#!/usr/bin/env bash
# planb-v19.sh — kernel: LED triggers for status LEDs.
# Adds CONFIG_LEDS_TRIGGER_HEARTBEAT (boot blink) + CONFIG_LEDS_TRIGGER_DISK
# (yellow IO LED). DTB/LED pins added in v19.1 after GPIO probe results.
set -euo pipefail

OUT=/workspace/output/planb-stock-uboot
SRC=/vol/kernel-src
B=/vol/kernel-build
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. enable LED trigger configs ==="
cd "$SRC"
# LEDS_TRIGGER_DISK depends on ATA (absent, unwanted) -> yellow LED uses a
# userspace /proc/diskstats poller instead. Only heartbeat is needed in-kernel.
./scripts/config --file "$B/.config" -e LEDS_TRIGGER_HEARTBEAT
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make O="$B" olddefconfig > /workspace/work/v19-config.log 2>&1
for opt in LEDS_TRIGGER_HEARTBEAT; do
  grep -q "CONFIG_${opt}=y" "$B/.config" || { echo "MISSING CONFIG_$opt"; exit 1; }
done
grep -E 'CONFIG_LEDS_TRIGGER_HEARTBEAT' "$B/.config"

echo "=== 2. rebuild zImage ==="
make -j"$(nproc)" O="$B" zImage > /workspace/work/v19-build.log 2>&1 || {
  tail -40 /workspace/work/v19-build.log; exit 1; }
tail -3 /workspace/work/v19-build.log
if strings "$B/vmlinux" | grep -q "FtlWrite: lpa error"; then echo "blob strings OK"; fi
nm "$B/vmlinux" | grep -w 'rk_ftl_udelay' > /dev/null && echo "udelay helper OK"
nm "$B/vmlinux" | grep -qw 'led_heartbeat_trigger' && echo "heartbeat trigger linked"

echo "=== 3. DTB (v17 for now; pins land in v19.1) ==="
W=/workspace/work
python3 /workspace/tools/v17-dts.py "$W/xmio-planb-v16.dts" "$W/xmio-planb-v17.dts"
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v17.dts" 2>/dev/null

echo "=== 4. repack (kernel ready, NOT flashing pins yet) ==="
python3 /workspace/tools/pack_resource.py "$OUT/resource.img" \
  "path=$OUT/rk3128-xmio-planb.dtb,name=rk-kernel.dtb"
cp -f "$B/arch/arm/boot/zImage" /workspace/output/kernel/zImage
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
k0,k1,r0,r1,s0,s1 = f[2],f[2]+f[1],f[4],f[4]+f[3],f[6],f[6]+f[5]
def ov(a0,a1,b0,b1): return max(a0,b0)<min(a1,b1)
assert not ov(k0,k1,s0,s1) and not ov(k0,k1,r0,r1) and not ov(r0,r1,s0,s1)
print('RAM LAYOUT OK')
EOF

echo "=== 5. hashes + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.v14diag.bak parameter.txt.v16.bak \
  parameter.txt.badnand1 parameter.txt.native uboot-stock.img misc.img \
  baseparamer-720P.img resource.img resource-baseline.img boot.img \
  rk3128-xmio-planb.dtb "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
md5sum "$OUT/boot.img" "$OUT/resource.img"
echo PLANB_V19_KERNEL_DONE
