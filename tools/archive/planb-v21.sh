#!/usr/bin/env bash
# planb-v21.sh — STOCK MODE: kernel adds CONFIG_LEDS_TRIGGER_NETDEV=y;
# DTB v19.4: dual LED ACTIVE_LOW + default-trigger heartbeat (boot red
# flicker) + default-state off. netdev is bound later by armbian-led-state
# restore (device_name/link persisted in /etc/armbian-leds.conf).
# Flash BOTH boot.img and resource.img. On-box: disable xmio-led,
# enable armbian-led-state, one-time netdev setup.
set -euo pipefail

OUT=/workspace/output/planb-stock-uboot
SRC=/vol/kernel-src
B=/vol/kernel-build
W=/workspace/work
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. kernel: enable netdev trigger ==="
cd "$SRC"
./scripts/config --file "$B/.config" -e LEDS_TRIGGER_NETDEV
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make O="$B" olddefconfig > /workspace/work/v21-config.log 2>&1
for opt in LEDS_TRIGGER_HEARTBEAT LEDS_TRIGGER_NETDEV; do
  grep -q "CONFIG_${opt}=y" "$B/.config" || { echo "MISSING CONFIG_$opt"; exit 1; }
done
grep -E 'CONFIG_LEDS_TRIGGER_(HEARTBEAT|NETDEV)' "$B/.config"

echo "=== 2. rebuild zImage ==="
make -j"$(nproc)" O="$B" zImage > /workspace/work/v21-build.log 2>&1 || {
  tail -40 /workspace/work/v21-build.log; exit 1; }
tail -3 /workspace/work/v21-build.log
nm "$B/vmlinux" | grep -qw 'netdev_trig_notify' && echo "netdev trigger linked"
nm "$B/vmlinux" | grep -qw 'led_heartbeat_trigger' && echo "heartbeat trigger linked"

echo "=== 3. DTB v19.4-stock ==="
python3 /workspace/tools/v19.4-dts.py "$W/xmio-planb-v19.3.dts" "$W/xmio-planb-v19.4.dts"
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v19.4.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null > /tmp/v194-check.dts
python3 - <<'EOF'
import re
d = open('/tmp/v194-check.dts').read()
assert 'local-mac-address = [02 31 28 16 01 28];' in d, 'MAC lost!'
i = d.index('\tmmc@10214000 {'); blk = d[i:i+900]
assert 'status = "okay";' in blk and 'broken-cd' in blk, 'sdmmc not enabled!'
a = d.index('\ttimer@20044000 {'); b2 = d.index('\ttimer@20044020 {')
assert a < b2, 'timer order wrong!'
leds = d[d.index('xmio-leds'):d.index('xmio-leds')+1400]
assert 'heartbeat' in leds, 'heartbeat default-trigger missing!'
assert re.search(r'gpios = <0x[0-9a-f]+ (?:0x0?8|8) 0x01>', leds), 'dual not ACTIVE_LOW!'
assert re.search(r'gpios = <0x[0-9a-f]+ (?:0x0?9|9) 0x01>', leds), 'yellow flag wrong!'
sb = leds[leds.index('status-led'):leds.index('status-led')+400]
assert 'default-state = "off"' in sb, 'status default-state not off!'
print('DTB verify OK (dual ACTIVE_LOW + heartbeat, yellow kept)')
EOF

echo "=== 4. repack ==="
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
echo PLANB_V21_STOCK_DONE
