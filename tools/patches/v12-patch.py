#!/usr/bin/env python3
"""v12-patch.py — kill the FTL-blob race + V12DIAG on request/GC paths.

Root cause chain established by the v11 log:
  - nand_gc_thread starts with rk_ftl_gc_do=1 and immediately calls the
    vendor FTL blob (rk_ftl_garbage_collect) CONCURRENTLY with the
    vendor-storage init blob calls made by nand_blk_register. The blob
    is not re-entrant -> GC hangs forever holding g_rk_nand_ops_mutex.
  - The first blkid read (initramfs udev rule 60-persistent-storage)
    blocks on that mutex -> udevadm settle waits forever -> boot stops
    right after "Starting systemd-udevd version ...".

Fix: disable background GC entirely (rk_ftl_gc_do stays 0; FUA/flush
requests still write back FTL cache), add V12DIAG counters around the
request path and GC path. Line-based, idempotent on "V12DIAG".
"""
import io
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "/vol/kernel-src"
BLK = SRC + "/drivers/rk_nand/rk_nand_blk.c"


def load(path):
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        return f.readlines()


def save(path, lines):
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.writelines(lines)


def find_one(lines, key):
    hits = [i for i, l in enumerate(lines) if key in l]
    if len(hits) != 1:
        raise SystemExit("FATAL: key %r hits %d (expected 1)" % (key, len(hits)))
    return hits[0]


def replace_next_after(lines, prev_key, key, new_line):
    """Replace the first line containing `key` that appears after the
    line containing `prev_key`."""
    p = find_one(lines, prev_key)
    for i in range(p + 1, len(lines)):
        if key in lines[i]:
            lines[i] = new_line
            return
    raise SystemExit("FATAL: no %r after %r" % (key, prev_key))


lines = load(BLK)
if "V12DIAG" in "".join(lines):
    print("SKIP %s (V12DIAG already present)" % BLK)
    sys.exit(0)

# 1. counters
idx = find_one(lines, "static unsigned long total_read_data;")
lines[idx + 1:idx + 1] = [
    "static unsigned int v12_rq_count;\n",
    "static unsigned int v12_gc_count;\n",
]
print("OK   counters after total_read_data")

# 2. thread start: no background GC at init (race killer)
idx = find_one(lines, "rk_ftl_gc_jiffies = HZ / 10;")
replace_next_after(lines, "rk_ftl_gc_jiffies = HZ / 10;",
                   "rk_ftl_gc_do = 1;",
                   "\trk_ftl_gc_do = 0; /* V12DIAG: no bg GC (blob race) */\n")
print("OK   gc_thread init gc_do 1 -> 0")

# 3. queue_rq: never re-arm background GC
replace_next_after(lines, "/* wake up gc thread */",
                   "rk_ftl_gc_do = 1;",
                   "\trk_ftl_gc_do = 0; /* V12DIAG: keep bg GC off */\n")
print("OK   queue_rq gc_do 1 -> 0")

# 4. request path diagnostics (first 8 requests)
idx = find_one(lines, "res = do_blktrans_all_request(req);")
lines[idx:idx] = [
    "\t\tif (v12_rq_count < 8)\n",
    "\t\t\tpr_warn(\"V12DIAG: rq start dev=%s sec=%llu nsec=%u\\n\",\n",
    "\t\t\t\treq->q->disk ? req->q->disk->disk_name : \"?\",\n",
    "\t\t\t\t(unsigned long long)blk_rq_pos(req),\n",
    "\t\t\t\tblk_rq_sectors(req));\n",
]
print("OK   rq start print")
idx = find_one(lines, "res = do_blktrans_all_request(req);")
lines[idx + 1:idx + 1] = [
    "\t\tif (v12_rq_count < 8)\n",
    "\t\t\tpr_warn(\"V12DIAG: rq done res=%d\\n\", (int)res);\n",
    "\t\tv12_rq_count++;\n",
]
print("OK   rq done print")

# 5. GC path diagnostics (fires only if GC is ever re-enabled)
idx = find_one(lines, "ftl_gc_status = rk_ftl_garbage_collect(1, 0);")
lines[idx:idx] = [
    "\t\t\t\tif (v12_gc_count < 3)\n",
    "\t\t\t\t\tpr_warn(\"V12DIAG: gc enter\\n\");\n",
]
print("OK   gc enter print")
idx = find_one(lines, "ftl_gc_status = rk_ftl_garbage_collect(1, 0);")
lines[idx + 1:idx + 1] = [
    "\t\t\t\tif (v12_gc_count < 3)\n",
    "\t\t\t\t\tpr_warn(\"V12DIAG: gc done status=%d\\n\",\n",
    "\t\t\t\t\t\tftl_gc_status);\n",
    "\t\t\t\tv12_gc_count++;\n",
]
print("OK   gc done print")

save(BLK, lines)
print("V12_PATCH_OK")
