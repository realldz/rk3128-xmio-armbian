#!/usr/bin/env bash
# v24.4-kernel.sh — doi co che defer-mac: counter-64-lan (bi deferred-probe
# freeze sao mai) -> blocking wait 10s roi fallback random MAC. Rebuild zImage.
set -euo pipefail
SRC=/vol/kernel-src
B=/vol/kernel-build
DW=$SRC/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c

echo "=== 1. patch dwmac-rk.c (idempotent) ==="
if grep -q "not ready after %ums" "$DW"; then
  echo "da patch tu truoc - bo qua"
else
  cp -n "$DW" "$DW.orig-v24.4" || true
  python3 - "$DW" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '''	/*
	 * MAC resolution: DT mac-address -> vendor storage (LAN_MAC_ID).
	 * Vendor storage lives behind rk_nand, which probes after us;
	 * defer until rk_vendor is ready so we never fall back to a
	 * random MAC on boxes whose vendor area is populated. Bounded
	 * retries keep brand-new boxes (empty vendor) booting normally.
	 */
	if (!is_valid_ether_addr(stmmac_res.mac) && !is_rk_vendor_ready()) {
		static atomic_t rk_gmac_vendor_defers;
		if (atomic_inc_return(&rk_gmac_vendor_defers) < 64)
			return -EPROBE_DEFER;
		pr_warn("rk_gmac: vendor storage not ready after 64 defers - using random MAC\\n");
	}'''
new = '''	/*
	 * MAC resolution: DT mac-address -> vendor storage (LAN_MAC_ID).
	 * Vendor storage lives behind rk_nand, which probes after us;
	 * wait (bounded) for rk_vendor so healthy boxes get the stored
	 * MAC, then fall back to a random MAC. Blocking wait instead of
	 * -EPROBE_DEFER: the deferred-probe core stops retrying after
	 * driver_deferred_probe_timeout (~15s), which starved the old
	 * defer-count escape hatch and left eth0 missing forever when
	 * vendor storage is dead. msleep is safe in probe context and
	 * rk_nand does not depend on us, so no deadlock.
	 */
	if (!is_valid_ether_addr(stmmac_res.mac) && !is_rk_vendor_ready()) {
		unsigned waited;
		for (waited = 0; waited < 10000 && !is_rk_vendor_ready();
		     waited += 100)
			msleep(100);
		if (!is_rk_vendor_ready())
			pr_warn("rk_gmac: vendor storage not ready after %ums - using random MAC\\n",
				waited);
	}'''
assert old in s, "OLD BLOCK KHONG TIM THAY - kernel da bi sua?"
s = s.replace(old, new)
open(p, "w").write(s)
print("patched OK")
PY
fi
grep -q "linux/delay.h" "$DW" || {
  python3 - "$DW" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("#include <linux/device.h>\n", "#include <linux/device.h>\n#include <linux/delay.h>\n", 1)
open(p, "w").write(s)
print("added linux/delay.h")
PY
}
grep -n "msleep(100)" "$DW" | head -2

echo "=== 2. rebuild zImage ==="
cd "$SRC"
export CROSS_COMPILE=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf- ARCH=arm LOCALVERSION=+
make -j"$(nproc)" O="$B" zImage > /workspace/work/v24.4-build.log 2>&1 || {
  tail -40 /workspace/work/v24.4-build.log; exit 1; }
tail -3 /workspace/work/v24.4-build.log

echo "=== 3. verify kernel moi ==="
strings "$B/vmlinux" | grep -c "vendor storage not ready after %ums" && echo "new warn string CO"
if strings "$B/vmlinux" | grep -q "after 64 defers"; then echo "LOI: string cu van con"; exit 1; fi
if nm "$B/vmlinux" | grep -qw rk_gmac_vendor_defers; then echo "LOI: counter cu van linked"; exit 1; fi
echo "counter cu da bien mat"
strings "$B/vmlinux" | grep -o "6\.6\.89-rk3128+" | head -1
echo V244_KERNEL_DONE
