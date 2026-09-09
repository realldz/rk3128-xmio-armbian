#!/usr/bin/env bash
# planb-v24.3.sh — v24.3: LED xanh default-on (DTB) + rootfs v23 với
# service LED (xanh enforce + vàng netdev wlan0). Rootfs: COPY v22 →
# v23 rồi sửa (v22 giữ nguyên làm rollback). Kernel không đổi.
set -euo pipefail

OUT=/workspace/output/planb-stock-uboot
B=/vol/kernel-build
W=/workspace/work
SRC=/vol/kernel-src

echo "=== 1. DTB: status-led default-on ==="
python3 /workspace/tools/v24.3-dts.py
cd "$SRC"
export CROSS_COMPILE=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf- ARCH=arm LOCALVERSION=+
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v23.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null > /tmp/v243-check.dts
python3 - <<'EOF'
import re
d = open('/tmp/v243-check.dts').read()
i = d.index('status-led {'); blk = d[i:i+320]
assert 'heartbeat' not in blk, 'heartbeat van con!'
assert 'default-state = "on"' in blk, 'green not default-on!'
assert re.search(r'gpios = <0x[0-9a-f]+ (?:0x0?8|8) 0x01>', blk), 'dual not ACTIVE_LOW!'
eb = d[d.index('io-led'):d.index('io-led')+260]
assert 'xmio:yellow:io' in eb, 'yellow gone!'
assert re.search(r'gpios = <0x[0-9a-f]+ (?:0x0?9|9) 0x01>', eb), 'yellow gpio changed!'
i = d.index('\tethernet@2008c000 {')
assert 'local-mac-address' not in d[i:i+1400], 'MAC regression!'
print('DTB v24.3 OK: green default-on, yellow io-led giu nguyen, MAC trong')
EOF

echo "=== 2. repack resource + boot (kernel giu nguyen v24.2) ==="
python3 /workspace/tools/pack_resource.py "$OUT/resource.img" \
  "path=$OUT/rk3128-xmio-planb.dtb,name=rk-kernel.dtb"
mkbootimg --kernel "$B/arch/arm/boot/zImage" \
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

echo "=== 3. rootfs: copy v22 -> v23 ==="
cp -f /workspace/output/armbian_rootfs_v22_xmio.img /workspace/output/armbian_rootfs_v23_xmio.img
sync; sleep 2

echo "=== 4. ghep file LED vao rootfs v23 (debugfs) ==="
bash /workspace/tools/v24.3-rootfs-files.sh
IMG=/workspace/output/armbian_rootfs_v23_xmio.img
LD=/workspace/work/ledrootfs
debugfs -w -R "write $LD/usr/local/sbin/xmio-led-green /usr/local/sbin/xmio-led-green" "$IMG"
debugfs -w -R "write $LD/etc/systemd/system/xmio-led-green.service /etc/systemd/system/xmio-led-green.service" "$IMG"
# enable: symlink wants/sysinit
debugfs -w -R "mkdir /etc/systemd/system/sysinit.target.wants" "$IMG" 2>/dev/null
debugfs -w -R "symlink /etc/systemd/system/sysinit.target.wants/xmio-led-green.service /etc/systemd/system/xmio-led-green.service" "$IMG"
sync; sleep 2

echo "=== 5. verify noi dung + symlink ==="
debugfs -R "cat /usr/local/sbin/xmio-led-green" "$IMG" | head -8
echo "--- service file ---"
debugfs -R "cat /etc/systemd/system/xmio-led-green.service" "$IMG" | head -4
echo "--- symlink ---"
debugfs -R "stat /etc/systemd/system/sysinit.target.wants/xmio-led-green.service" "$IMG" | head -8
echo "--- chmod 755 script? (mode cua write la 0644 - can sua) ---"
debugfs -R "sif /usr/local/sbin/xmio-led-green mode 0100755" "$IMG"
debugfs -R "stat /usr/local/sbin/xmio-led-green" "$IMG" | grep -E 'Mode|User'

echo "=== 6. hashes + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.native misc.img baseparamer-720P.img \
  uboot-stock.img resource.img boot.img rk3128-xmio-planb.dtb \
  initrd.img.gz "rk3128MiniLoaderAll(L)_V2.25_ink.bin" \
  onbox/vendor-mac onbox/xmio-led-arm onbox/xmio-led.service > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
cd /workspace/output && rm -f SHA256SUMS.txt
sha256sum armbian_rootfs_v23_xmio.img > SHA256SUMS.txt
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
md5sum "$OUT/boot.img" "$OUT/resource.img" armbian_rootfs_v23_xmio.img
echo PLANB_V243_DONE