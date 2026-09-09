#!/usr/bin/env bash
# v24.4c-kernel.sh — dwmac-rk: yield + self-retrigger
# Root cause vòng 4: blocking wait trong probe CHIEM luồng deferred-probe
# đơn-luồng → rk_nand (backend vendor storage, nằm SAU gmac trong hàng đợi)
# bị đói → "init ok" chỉ xuất hiện SAU khi gmac bỏ cuộc (+2.0s đều ở 2 vòng).
# Fix: yield (-EPROBE_DEFER) như kernel cũ; core đóng băng sau ~15s nên tự
# lái retry bằng delayed work 2s + device_attach(); deadline 30s cho box
# vendor chết thật.
set -euo pipefail
SRC=/vol/kernel-src
B=/vol/kernel-build
OUT=/workspace/output/planb-stock-uboot
F=$SRC/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c
export CROSS_COMPILE=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf- ARCH=arm LOCALVERSION=+

echo "=== 1. patch dwmac-rk.c ==="
[ -f "$F.orig-v24.4" ] || cp "$F" "$F.orig-v24.4"
python3 - <<'PYEOF'
import re, sys
p = '/vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c'
s = open(p).read()
if 'rk_gmac_vendor_reprobe' in s:
    print('ALREADY PATCHED'); sys.exit(0)
if '#include <linux/workqueue.h>' not in s:
    s = s.replace('#include <linux/delay.h>',
                  '#include <linux/delay.h>\n#include <linux/workqueue.h>', 1)

pat = re.compile(
    r'\t/\*\n\t \* MAC resolution:.*?\n\t \*/\n'
    r'\tif \(!is_valid_ether_addr\(stmmac_res\.mac\) && !is_rk_vendor_ready\(\)\) \{.*?\n\t\}\n',
    re.S)
if not pat.search(s):
    print('PATTERN NOT FOUND'); sys.exit(1)

new = '''    /*
     * MAC resolution: DT mac-address -> vendor storage (LAN_MAC_ID).
     * Vendor storage lives behind rk_nand, which probes AFTER us on the
     * same single-threaded deferred-probe queue, so the only correct
     * posture is to YIELD (-EPROBE_DEFER): blocking inside probe starves
     * rk_nand behind us (v24.4a/b regression - "init ok" appeared only
     * after we gave up). The deferred-probe core stops requeuing after
     * its own ~15s timeout, so retries are driven by a 2s delayed work +
     * device_attach(); the 30s deadline is the escape hatch for boxes
     * whose vendor area is dead.
     */
    if (!is_valid_ether_addr(stmmac_res.mac) && !is_rk_vendor_ready()) {
        if (!rk_gmac_first_defer_jif)
            rk_gmac_first_defer_jif = jiffies;
        if (time_is_before_jiffies(rk_gmac_first_defer_jif + 30 * HZ)) {
            pr_warn("rk_gmac: vendor storage not ready after 30s - using random MAC\\n");
            cancel_delayed_work(&rk_gmac_vendor_reprobe);
        } else {
            rk_gmac_reprobe_pdev = pdev;
            schedule_delayed_work(&rk_gmac_vendor_reprobe, 2 * HZ);
            return -EPROBE_DEFER;
        }
    }
'''
s = pat.sub(lambda m: new, s, count=1)

statics = '''/*
 * v24.4c: rk_nand (vendor storage backend) probes after us on the same
 * single-threaded deferred-probe queue. Probe yields; retries are driven
 * here because the deferred-probe core freezes after its ~15s timeout.
 */
static unsigned long rk_gmac_first_defer_jif;
static struct platform_device *rk_gmac_reprobe_pdev;
static void rk_gmac_vendor_reprobe_fn(struct work_struct *w);
static DECLARE_DELAYED_WORK(rk_gmac_vendor_reprobe,
                rk_gmac_vendor_reprobe_fn);

static void rk_gmac_vendor_reprobe_fn(struct work_struct *w)
{
    struct platform_device *pdev = rk_gmac_reprobe_pdev;

    if (pdev)
        device_attach(&pdev->dev);
    if (!is_rk_vendor_ready() &&
        !time_is_before_jiffies(rk_gmac_first_defer_jif + 32 * HZ))
        schedule_delayed_work(&rk_gmac_vendor_reprobe, 2 * HZ);
}

'''
idx = s.index('static int rk_gmac_probe(')
s = s[:idx] + statics + s[idx:]
open(p, 'w').write(s)
print('PATCHED OK')
PYEOF
grep -n "rk_gmac_vendor_reprobe_fn\|return -EPROBE_DEFER;" "$F" | head -8

echo "=== 2. rebuild zImage #26 ==="
cd "$SRC"
make -j"$(nproc)" O="$B" zImage > /workspace/work/v24.4c-build.log 2>&1 || {
  tail -40 /workspace/work/v24.4c-build.log; exit 1; }
tail -2 /workspace/work/v24.4c-build.log
strings "$B/vmlinux" | grep -c "not ready after 30s"
if strings "$B/vmlinux" | grep -q "not ready after %ums"; then
  echo "ERROR: old blocking string still present"; exit 1
fi
echo "old string gone OK"

echo "=== 3. pack boot v24.4c ==="
[ -f /workspace/output/archive/boot-v24.4b.img ] || cp "$OUT/boot.img" /workspace/output/archive/boot-v24.4b.img
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
psize = struct.unpack_from('<I', d, 36)[0]
ksize = struct.unpack_from('<I', d, 8)[0]
z = open('/vol/kernel-build/arch/arm/boot/zImage','rb').read()
assert d[psize:psize+ksize] == z, 'kernel mismatch!'
print('KERNEL MATCH OK')
EOF

echo "=== 4. md5 ==="
md5sum "$OUT/boot.img" "$B/arch/arm/boot/zImage"
echo V244C_DONE
