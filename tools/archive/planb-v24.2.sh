#!/usr/bin/env bash
# planb-v24.2.sh — v24.2: /proc/cpuinfo đúng (machine + serial per-device
# từ efuse chip-ID). MAC/vendor storage KHÔNG đụng tới.
set -euo pipefail

OUT=/workspace/output/planb-stock-uboot
SRC=/vol/kernel-src
B=/vol/kernel-build
W=/workspace/work
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. kernel patches (dt_compat + serial string) ==="
python3 /workspace/tools/v24.2-kpatch.py

echo "=== 2. DTB: chen node cpuinfo ==="
python3 /workspace/tools/v24.2-dts.py

echo "=== 3. rebuild zImage ==="
cd "$SRC"
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make -j"$(nproc)" O="$B" zImage > /workspace/work/v242-build.log 2>&1 || {
  tail -40 /workspace/work/v242-build.log; exit 1; }
tail -2 /workspace/work/v242-build.log
strings "$B/vmlinux" | grep -q 'rockchip,rk3128' && echo "compat string in vmlinux OK"
nm "$B/vmlinux" | grep -qw 'rockchip_soc_id_init' && echo "soc_id_init present"

echo "=== 4. DTB compile + verify toan dien ==="
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v23.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null > /tmp/v242-check.dts
python3 - <<'EOF'
import re
d = open('/tmp/v242-check.dts').read()
i = d.index('\tethernet@2008c000 {'); blk = d[i:i+1400]
assert 'local-mac-address' not in blk, 'MAC in DTB - wrong!'
assert 'status = "okay"' in blk
assert re.search(r'gpios = <0x[0-9a-f]+ (?:0x0?8|8) 0x01>', d), 'dual not ACTIVE_LOW!'
sb = d[d.index('status-led'):d.index('status-led')+400]
assert 'heartbeat' in sb and 'default-state = "off"' in sb, 'LED regression!'
assert 'broken-cd' in d, 'sdmmc regression!'
i = d.index('\tcpuinfo {')
cb = d[i:i+300]
assert 'compatible = "rockchip,cpuinfo"' in cb
ph = re.search(r'nvmem-cells = <(0x[0-9a-f]+)>;', cb).group(1)
em = re.search(r'id@7 \{\s*reg = <0x0?7 0x10>;\s*phandle = <(0x[0-9a-f]+)>;', d)
assert ph == em.group(1), f'phandle mismatch: cells {ph} vs id@7 {em.group(1)}'
print(f'DTB v24.2 OK: cpuinfo -> efuse id@7 (phandle {ph}), MAC/LED/SDMMC intact')
EOF

echo "=== 5. repack boot + resource (CA HAI doi - DTB moi) ==="
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

echo "=== 6. hashes + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.native misc.img baseparamer-720P.img \
  uboot-stock.img resource.img boot.img rk3128-xmio-planb.dtb \
  initrd.img.gz "rk3128MiniLoaderAll(L)_V2.25_ink.bin" \
  onbox/vendor-mac onbox/xmio-led-arm onbox/xmio-led.service > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
md5sum "$OUT/boot.img" "$OUT/resource.img"
echo PLANB_V242_DONE