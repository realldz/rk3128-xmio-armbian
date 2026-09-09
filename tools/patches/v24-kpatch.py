#!/usr/bin/env python3
# v24-kpatch.py — rk_nand_blk.c: expose /dev/vendor_storage even when the
# FTL vendor-area scan fails. The blob's ioctl (rk_ftl_vendor_storage_ioctl)
# then handles VENDOR_WRITE_IO from userspace; the first write is expected
# to FORMAT the vendor area (FtlVendorPartWrite path). Empirical: if the
# blob refuses, we fall back to the uboot-env solution (v23.3).
import shutil, sys

P = '/vol/kernel-src/drivers/rk_nand/rk_nand_blk.c'
src = open(P).read()

OLD = '''	} else {
		pr_info("rknand vendor storage init failed !\\n");
	}'''
NEW = '''	} else {
		pr_info("rknand vendor storage init failed (%d) - exposing vendor_storage ioctl node for userspace\\n", ret);
		rknand_vendor_storage_init();
	}'''

if NEW in src:
    print('already patched (idempotent)')
elif OLD in src:
    shutil.copy(P, P + '.orig-v23')
    src = src.replace(OLD, NEW, 1)
    open(P, 'w').write(src)
    print('patched: /dev/vendor_storage now registered unconditionally')
else:
    sys.exit('anchor not found - abort')
