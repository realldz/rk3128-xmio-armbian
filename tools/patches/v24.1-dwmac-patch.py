#!/usr/bin/env python3
# v24.1-dwmac-patch.py — dwmac-rk.c: defer gmac probe until the vendor
# storage backend is ready, whenever the DTB carries no MAC. Bounded to
# 64 defers so a box with an empty vendor area still gets a random MAC
# (and a working interface) instead of no ethernet at all.
import shutil, sys

P = '/vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c'
src = open(P).read()

ANCHOR = '''	plat_dat = stmmac_probe_config_dt(pdev, stmmac_res.mac);
	if (IS_ERR(plat_dat))
		return PTR_ERR(plat_dat);
'''

PATCH = '''	plat_dat = stmmac_probe_config_dt(pdev, stmmac_res.mac);
	if (IS_ERR(plat_dat))
		return PTR_ERR(plat_dat);

	/*
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
	}
'''

if 'is_rk_vendor_ready()' in src and 'rk_gmac_vendor_defers' in src:
    print('already patched (idempotent)')
else:
    if ANCHOR not in src:
        sys.exit('anchor not found - abort')
    if '#include <linux/soc/rockchip/rk_vendor_storage.h>' not in src:
        src = src.replace('#include "stmmac_platform.h"',
                          '#include <linux/soc/rockchip/rk_vendor_storage.h>\n#include "stmmac_platform.h"', 1)
    src = src.replace(ANCHOR, PATCH, 1)
    shutil.copy(P, P + '.orig-v24')
    open(P, 'w').write(src)
    print('patched: gmac defers until vendor storage ready (bounded 64)')
