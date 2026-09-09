#!/usr/bin/env bash
# planb-v23.sh — v23: MAC gốc từ vendor storage (LAN_MAC_ID).
# ROOT CAUSE của "kernel không đọc được MAC": dtb gán cứng
# local-mac-address=02:31:28:16:01:28 → of_get_mac_address ưu tiên
# DT trước nvmem/vendor → stmmac_check_ether_addr thấy addr hợp lệ
# → KHÔNG BAO GIỜ gọi rk_get_eth_addr → không bao giờ hỏi
# rk_vendor_read(LAN_MAC_ID=3) mà Android stock đã ghi.
# FIX: bỏ local-mac-address khỏi DTS; bật
# CONFIG_ROCKCHIP_VENDOR_STORAGE=y (rk_vendor_storage.c) — backend
# đã có sẵn trong RK_NAND: rk_nand_blk.c gọi rk_ftl_vendor_storage_
# init() + rk_vendor_register() + /dev/vendor_storage.
# dtb v23 (từ v19.4): xoá dòng local-mac-address.
# BOOT LOG VERIFY: "rknand vendor storage init ok !" +
# "rk_get_eth_addr: mac address: xx:xx:..." (xuất hiện IFF vendor
# storage trả MAC hợp lệ — nếu DT cũng trống).
set -euo pipefail

OUT=/workspace/output/planb-stock-uboot
SRC=/vol/kernel-src
B=/vol/kernel-build
W=/workspace/work
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. kernel: enable vendor storage core ==="
cd "$SRC"
./scripts/config --file "$B/.config" -e ROCKCHIP_VENDOR_STORAGE
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make O="$B" olddefconfig > /workspace/work/v23-config.log 2>&1
for opt in ROCKCHIP_VENDOR_STORAGE RK_NAND LEDS_TRIGGER_NETDEV; do
  grep -q "CONFIG_${opt}=y" "$B/.config" || { echo "MISSING CONFIG_$opt"; exit 1; }
done
grep -E 'CONFIG_(ROCKCHIP_VENDOR_STORAGE|RK_NAND|LEDS_TRIGGER_NETDEV)' "$B/.config"

echo "=== 2. rebuild zImage ==="
make -j"$(nproc)" O="$B" zImage > /workspace/work/v23-build.log 2>&1 || {
  tail -40 /workspace/work/v23-build.log; exit 1; }
tail -3 /workspace/work/v23-build.log
nm "$B/vmlinux" | grep -qw 'rk_vendor_read' && echo "rk_vendor_read linked"
nm "$B/vmlinux" | grep -qw 'rk_vendor_register' && echo "rk_vendor_register linked"
nm "$B/vmlinux" | grep -qw 'rk_ftl_vendor_read' && echo "rk_ftl_vendor_read linked"
nm "$B/vmlinux" | grep -qw 'rk_get_eth_addr' && echo "rk_get_eth_addr linked"

echo "=== 3. DTB v23 (strip hardcoded MAC from v19.4) ==="
python3 /workspace/tools/v23-dts.py "$W/xmio-planb-v19.4.dts" "$W/xmio-planb-v23.dts"
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v23.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null > /tmp/v23-check.dts
python3 - <<'EOF'
import re
d = open('/tmp/v23-check.dts').read()
i = d.index('\tethernet@2008c000 {'); blk = d[i:i+1400]
assert 'local-mac-address' not in blk, 'hardcoded MAC still present!'
assert 'status = "okay"' in blk, 'eth not enabled!'
assert re.search(r'gpios = <0x[0-9a-f]+ (?:0x0?8|8) 0x01>', d), 'dual not ACTIVE_LOW!'
sb = d[d.index('status-led'):d.index('status-led')+400]
assert 'heartbeat' in sb and 'default-state = "off"' in sb, 'LED regression!'
a = d.index('\ttimer@20044000 {'); b2 = d.index('\ttimer@20044020 {')
assert a < b2, 'timer order wrong!'
assert 'broken-cd' in d, 'sdmmc regression!'
print('DTB verify OK (no hardcoded MAC, LEDs intact)')
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
echo PLANB_V23_DONE
