#!/usr/bin/env bash
# planb-v15.1.sh — stable ethernet MAC via DTB local-mac-address.
# Root cause: rk vendor storage init fails inside the FTL (IDB area,
# ReadRetry/ECC), so rk_vendor_read/write(-1) -> random MAC every boot.
# Fix: stmmac_probe_config_dt reads local-mac-address -> eth_hw_addr_set
# BEFORE stmmac_check_ether_addr -> vendor hook never runs.
# Rebuild: DTB (dts v8 + mac) -> resource.img (RSCE repack) -> boot.img.
# Flash: resource.img -> 0x6800, boot.img -> 0xE000.
set -euo pipefail

W=/workspace/work
OUT=/workspace/output/planb-stock-uboot
MAC="02:31:28:16:01:28"

echo "=== 1. inject local-mac-address ($MAC) into planb DTS ==="
python3 - "$W/xmio-planb-v8.dts" "$W/xmio-planb-v9.dts" "$MAC" <<'EOF'
import sys
src, dst, mac = sys.argv[1], sys.argv[2], sys.argv[3]
b = bytes(int(x, 16) for x in mac.split(':'))
prop = 'local-mac-address = [%s];' % ' '.join('%02x' % x for x in b)
d = open(src, encoding='utf-8').read()
if 'local-mac-address' in d:
    print('already present in source, copying as-is')
else:
    i = d.index('ethernet@2008c000 {')
    j = d.index('status = "okay";', i)
    d = d[:j] + prop + '\n\t\t' + d[j:]
open(dst, 'w', encoding='utf-8').write(d)
print('written', dst)
EOF

dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v9.dts" 2>/dev/null
if dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null | grep 'local-mac-address' ; then
  echo "DTB MAC OK"
else
  echo "FATAL: local-mac-address missing in compiled dtb"; exit 1
fi

echo "=== 2. repack resource.img (RSCE, single rk-kernel.dtb entry) ==="
python3 /workspace/tools/pack_resource.py "$OUT/resource.img" \
  "path=$OUT/rk3128-xmio-planb.dtb,name=rk-kernel.dtb"

echo "=== 3. repack boot.img (zImage v15-release + v13 initramfs) ==="
mkbootimg --kernel /workspace/output/kernel/zImage \
  --ramdisk "$OUT/initrd.img.gz" \
  --second "$OUT/resource.img" \
  --base 0x60000000 --kernel_offset 0x00408000 \
  --ramdisk_offset 0x02000000 --second_offset 0x00F00000 \
  --tags_offset 0x00088000 --pagesize 16384 \
  --cmdline "" --output "$OUT/boot.img"

echo "=== 4. layout assert ==="
python3 - <<'EOF'
import struct
d = open('/workspace/output/planb-stock-uboot/boot.img','rb').read()
f = struct.unpack_from('<8s10I', d, 0)
k0,k1,r0,r1,s0,s1 = f[2],f[2]+f[1],f[4],f[4]+f[3],f[6],f[6]+f[5]
def ov(a0,a1,b0,b1): return max(a0,b0)<min(a1,b1)
assert not ov(k0,k1,s0,s1) and not ov(k0,k1,r0,r1) and not ov(r0,r1,s0,s1)
print('kernel %d | ramdisk %d | second %d @ %#x | RAM LAYOUT OK' % (f[1],f[3],f[5],f[6]))
EOF

echo "=== 5. hashes + bundle ==="
cd "$OUT" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.v14diag.bak uboot-stock.img misc.img \
  baseparamer-720P.img resource.img resource-baseline.img boot.img \
  rk3128-xmio-planb.dtb "rk3128MiniLoaderAll(L)_V2.25_ink.bin" > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
echo PLANB_V15_1_MAC_DONE
