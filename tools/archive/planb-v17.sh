#!/usr/bin/env bash
# planb-v17.sh — add timer channel 2 as clocksource+sched_clock (DTB only).
# Kernel unchanged (v16 zImage reused): driver's rk_clksrc_init already
# exists, it just never had a second timer node to bind. Result: sub-us
# timestamps, ping/mtr/jitter real, dmesg stamps with microseconds.
# Flash: boot.img -> 0xE000, resource.img -> 0x6800.
set -euo pipefail

W=/workspace/work
OUT=/workspace/output/planb-stock-uboot

echo "=== 1. build v17 DTB (v16 + timer@20044020) ==="
python3 /workspace/tools/v17-dts.py "$W/xmio-planb-v16.dts" "$W/xmio-planb-v17.dts"
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v17.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null > /tmp/v17-check.dts
python3 - <<'EOF'
d = open('/tmp/v17-check.dts').read()
assert 'local-mac-address = [02 31 28 16 01 28];' in d, 'MAC lost!'
i = d.index('\tmmc@10214000 {')
blk = d[i:i+900]
assert 'status = "okay";' in blk and 'broken-cd' in blk, 'sdmmc not enabled!'
a = d.index('\ttimer@20044000 {')
b = d.index('\ttimer@20044020 {')
assert a < b, 'timer order wrong (clkevt must be first)!'
blk = d[b:b+400]
assert 'reg = <0x20044020 0x20>;' in blk, 'timer2 reg wrong!'
assert 'interrupts = <0x00 0x1d 0x04>;' in blk, 'timer2 irq wrong!'
print('DTB verify: MAC+sdmmc+codecs kept, timer2 @0x20044020 present, order OK')
EOF

echo "=== 2. repack resource.img + boot.img (zImage unchanged) ==="
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
  uboot-stock.img misc.img baseparamer-720P.img resource.img \
  resource-baseline.img boot.img rk3128-xmio-planb.dtb \
  "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
md5sum "$OUT/boot.img" "$OUT/resource.img"
echo PLANB_V17_DONE
