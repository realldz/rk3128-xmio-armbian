#!/usr/bin/env bash
# planb-v24.1.sh — "theo vendor" hoàn toàn:
#   - DTB v23: KHÔNG local-mac-address (bỏ fix cứng v23.2)
#   - kernel v24.1: gmac defer probe đến khi vendor storage sẵn sàng
#     (bounded 64 — box mới chưa ghi vẫn boot random bình thường)
#   - /dev/vendor_storage vẫn expose (tool ghi lần đầu cho box mới)
# uboot-planb-mac deprecated (env MAC = fix cứng per-image, hại multi-box).
set -euo pipefail

OUT=/workspace/output/planb-stock-uboot
SRC=/vol/kernel-src
B=/vol/kernel-build
W=/workspace/work
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. patch dwmac-rk (defer until vendor ready) ==="
python3 /workspace/tools/v24.1-dwmac-patch.py

echo "=== 2. rebuild zImage v24.1 ==="
cd "$SRC"
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make -j"$(nproc)" O="$B" zImage > /workspace/work/v241-build.log 2>&1 || {
  tail -40 /workspace/work/v241-build.log; exit 1; }
tail -2 /workspace/work/v241-build.log
nm "$B/vmlinux" | grep -q 'is_rk_vendor_ready' && echo "is_rk_vendor_ready linked"
nm "$B/vmlinux" | grep -q 'rk_vendor_register' && echo "rk_vendor_register linked"
strings "$B/vmlinux" | grep -q 'vendor storage not ready after 64' && echo "defer warn string OK"

echo "=== 3. DTB v23 (khong MAC cung) ==="
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v23.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null > /tmp/v241-check.dts
python3 - <<'EOF'
import re
d = open('/tmp/v241-check.dts').read()
i = d.index('\tethernet@2008c000 {'); blk = d[i:i+1400]
assert 'local-mac-address' not in blk, 'MAC still in DTB!'
assert 'status = "okay"' in blk
assert re.search(r'gpios = <0x[0-9a-f]+ (?:0x0?8|8) 0x01>', d), 'dual not ACTIVE_LOW!'
sb = d[d.index('status-led'):d.index('status-led')+400]
assert 'heartbeat' in sb and 'default-state = "off"' in sb, 'LED regression!'
assert 'broken-cd' in d, 'sdmmc regression!'
print('DTB v23.1 OK: no local-mac-address, LEDs intact')
EOF

echo "=== 4. backup + repack ==="
[ -f "$OUT/resource.img.v23.2-mac.bak" ] || cp -f "$OUT/resource.img" "$OUT/resource.img.v23.2-mac.bak"
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

echo "=== 5. hashes + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.v14diag.bak parameter.txt.v16.bak \
  parameter.txt.badnand1 parameter.txt.native uboot-stock.img uboot-planb-mac.img \
  misc.img baseparamer-720P.img resource.img resource-baseline.img \
  resource.img.v23.2-mac.bak boot.img boot-v23.img \
  rk3128-xmio-planb.dtb "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
md5sum "$OUT/boot.img" "$OUT/resource.img"
echo PLANB_V241_DONE
