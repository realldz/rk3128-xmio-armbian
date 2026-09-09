#!/usr/bin/env bash
# planb-v18.2.sh — enable task I/O accounting (iotop / pidstat / /proc/pid/io).
# Adds: CONFIG_TASKSTATS, TASK_DELAY_ACCT, TASK_XACCT, TASK_IO_ACCOUNTING.
# Everything else identical to v18. Flash: boot.img -> 0xE000,
# resource.img -> 0x6800. Plus on-box: sysctl kernel.task_delayacct=1.
set -euo pipefail

W=/workspace/work
OUT=/workspace/output/planb-stock-uboot
SRC=/vol/kernel-src
B=/vol/kernel-build
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-

echo "=== 1. enable IO accounting configs ==="
cd "$SRC"
./scripts/config --file "$B/.config" \
  -e TASKSTATS -e TASK_DELAY_ACCT -e TASK_XACCT -e TASK_IO_ACCOUNTING
export CROSS_COMPILE="$CROSS" ARCH=arm LOCALVERSION=+
make O="$B" olddefconfig > /workspace/work/v18.2-config.log 2>&1
grep -E 'CONFIG_TASKSTATS|CONFIG_TASK_DELAY_ACCT|CONFIG_TASK_XACCT|CONFIG_TASK_IO_ACCOUNTING' "$B/.config"
for opt in TASKSTATS TASK_DELAY_ACCT TASK_XACCT TASK_IO_ACCOUNTING; do
  grep -q "CONFIG_${opt}=y" "$B/.config" || { echo "MISSING CONFIG_$opt"; exit 1; }
done
grep -E 'CONFIG_TASKSTATS|CONFIG_TASK_DELAY_ACCT|CONFIG_TASK_XACCT|CONFIG_TASK_IO_ACCOUNTING' "$B/.config" > /tmp/v182-cfg
python3 - <<'EOF'
cfg = open('/tmp/v182-cfg').read()
assert cfg.count('=y') == 4, cfg
print('CONFIG verify: all 4 accounting opts =y')
EOF

echo "=== 2. rebuild zImage ==="
make -j"$(nproc)" O="$B" zImage > /workspace/work/v18.2-build.log 2>&1 || {
  tail -40 /workspace/work/v18.2-build.log; exit 1; }
tail -3 /workspace/work/v18.2-build.log
if strings "$B/vmlinux" | grep -q "FtlWrite: lpa error"; then echo "blob strings OK"; fi
nm "$B/vmlinux" | grep -w 'rk_ftl_udelay' > /dev/null && echo "udelay helper OK"
nm "$B/vmlinux" | grep -qw 'taskstats_exit_cmd' || nm "$B/vmlinux" | grep -q 'taskstats' && echo "taskstats linked"

echo "=== 3. DTB (v17, unchanged) ==="
python3 /workspace/tools/v17-dts.py "$W/xmio-planb-v16.dts" "$W/xmio-planb-v17.dts"
dtc -I dts -O dtb -o "$OUT/rk3128-xmio-planb.dtb" "$W/xmio-planb-v17.dts" 2>/dev/null
dtc -I dtb -O dts "$OUT/rk3128-xmio-planb.dtb" 2>/dev/null > /tmp/v182-check.dts
python3 - <<'EOF'
d = open('/tmp/v182-check.dts').read()
assert 'local-mac-address = [02 31 28 16 01 28];' in d, 'MAC lost!'
i = d.index('\tmmc@10214000 {')
blk = d[i:i+900]
assert 'status = "okay";' in blk and 'broken-cd' in blk, 'sdmmc not enabled!'
a = d.index('\ttimer@20044000 {'); b2 = d.index('\ttimer@20044020 {')
assert a < b2, 'timer order wrong!'
print('DTB verify OK')
EOF

echo "=== 4. repack resource.img + boot.img ==="
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
echo PLANB_V18_2_DONE
