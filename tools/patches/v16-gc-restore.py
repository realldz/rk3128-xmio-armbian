#!/usr/bin/env python3
# v16-gc-restore.py — restore vendor background GC in rk_nand_blk.c,
# gated so it can NEVER race the vendor-storage init (v11 deadlock).
#
# Why: v12 disabled GC because the FTL blob hung when nand_gc_thread
# (spawned at nand_blk register time) ran rk_ftl_garbage_collect()
# concurrently with rk_ftl_vendor_storage_init(). On THIS box the IDB
# region is damaged (ReadRetry err=ffffffff), so init takes ~8-12s and
# the race window is wide. The freeze that motivated v12 was later
# proven to be the tick timer (fixed v14), so GC is restored as vendor
# shipped, plus a v16_ftl_ready flag that releases GC only after the
# vendor-storage init call has RETURNED (success or failure).
#
# Idempotent on marker "V16GC_READY".
import io

P = "/vol/kernel-src/drivers/rk_nand/rk_nand_blk.c"
with io.open(P, "r", encoding="utf-8") as f:
    s = f.read()

if "V16GC_READY" in s:
    n1 = s.count("\trk_ftl_gc_do = 1;\n")
    assert n1 >= 2, "unexpected GC arming sites: %d" % n1
    print("V16_GC_RESTORE_OK: already patched (%d arming sites, gate on)" % n1)
    raise SystemExit(0)


def rep1(old, new):
    global s
    n = s.count(old)
    assert n == 1, "anchor x%d: %r" % (n, old[:70])
    s = s.replace(old, new)


def maybe(old, new):
    global s
    if old in s:
        rep1(old, new)
        return True
    return False


# 1. undo v12/V15 gc_do=0 workarounds -> vendor original =1
changed = 0
changed += maybe("\trk_ftl_gc_do = 0; /* V15RELEASE_MARKER: bg GC off */\n",
                 "\trk_ftl_gc_do = 1;\n")
changed += maybe("\trk_ftl_gc_do = 0; /* bg GC off */\n",
                 "\trk_ftl_gc_do = 1;\n")
if not changed:
    n1 = s.count("\trk_ftl_gc_do = 1;\n")
    assert n1 >= 2, "GC arming sites missing: %d" % n1

# 2. ready flag declaration
if not maybe("static unsigned long rk_ftl_gc_do;\n",
             "static unsigned long rk_ftl_gc_do;\n"
             "static bool v16_ftl_ready; /* V16GC_READY: gate vs vendor init */\n"):
    assert "v16_ftl_ready" in s

# 3. gate the GC branch in the thread
assert maybe("\t\tif (rk_ftl_gc_do) {\n",
             "\t\tif (rk_ftl_gc_do && v16_ftl_ready) {\n")

# 4. release the gate when vendor-storage init returns (either way)
assert maybe("\tret = rk_ftl_vendor_storage_init();\n",
             "\tv16_ftl_ready = true; /* V16GC_READY: init window closed */\n"
             "\tret = rk_ftl_vendor_storage_init();\n")

with io.open(P, "w", encoding="utf-8", newline="") as f:
    f.write(s)
print("V16_GC_RESTORE_OK: vendor GC restored + v16_ftl_ready gate applied")
