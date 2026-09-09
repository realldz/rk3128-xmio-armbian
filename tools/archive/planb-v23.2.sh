#!/usr/bin/env bash
# planb-v23.2.sh — DTB v23.2: gán MAC tem nhãn B8:3D:4E:84:3D:A3 vào
# local-mac-address của gmac (factory label MAC; efuse KHÔNG chứa MAC,
# IDB cũng 00:00:00:00:00:00 ngay trên Android stock → nhãn là nguồn
# gốc duy nhất). MAC sống trong boot/resource → không sợ reflash
# rootfs, không random mỗi boot. Kernel không đổi.
set -euo pipefail

OUT=/workspace/output/planb-stock-uboot
W=/workspace/work

echo "=== 1. DTB v23.2 ==="
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v23.2.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null > /tmp/v232-check.dts
python3 - <<'EOF'
import re
d = open('/tmp/v232-check.dts').read()
i = d.index('\tethernet@2008c000 {'); blk = d[i:i+1500]
m = re.search(r'local-mac-address = \[([0-9a-f ]+)\];', blk)
assert m, 'local-mac-address missing!'
b = bytes.fromhex(m.group(1).replace(' ', ''))
assert b == bytes([0xB8,0x3D,0x4E,0x84,0x3D,0xA3]), f'wrong MAC: {b.hex()}'
assert 'status = "okay"' in blk, 'eth not enabled!'
assert re.search(r'gpios = <0x[0-9a-f]+ (?:0x0?8|8) 0x01>', d), 'dual not ACTIVE_LOW!'
sb = d[d.index('status-led'):d.index('status-led')+400]
assert 'heartbeat' in sb and 'default-state = "off"' in sb, 'LED regression!'
a = d.index('\ttimer@20044000 {'); b2 = d.index('\ttimer@20044020 {')
assert a < b2, 'timer order wrong!'
assert 'broken-cd' in d, 'sdmmc regression!'
print('DTB verify OK (label MAC B8:3D:4E:84:3D:A3, LEDs intact)')
EOF

echo "=== 2. repack ==="
python3 /workspace/tools/pack_resource.py "$OUT/resource.img" \
  "path=$OUT/rk3128-xmio-planb.dtb,name=rk-kernel.dtb"
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

echo "=== 3. hashes + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.v14diag.bak parameter.txt.v16.bak \
  parameter.txt.badnand1 parameter.txt.native uboot-stock.img misc.img \
  baseparamer-720P.img resource.img resource-baseline.img boot.img \
  rk3128-xmio-planb.dtb "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
md5sum "$OUT/boot.img" "$OUT/resource.img"
echo PLANB_V232_DONE
