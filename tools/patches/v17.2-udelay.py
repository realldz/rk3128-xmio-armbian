#!/usr/bin/env python3
# v17.2-udelay.py — fix ftlv5 blob's usleep_range quantization.
#
# Root cause of slow IO: blob rk_ftlv5_arm32.S polls NAND completion with
# usleep_range(1..5 us) — intended as microsecond settle delays. Our
# kernel runs without CONFIG_HIGH_RES_TIMERS (v13 decision) and HZ=100,
# so every usleep_range quantizes to a full 10ms tick. Per 16KB LPN the
# blob sleeps ~2 ticks = 20ms -> measured 20.9ms/page -> 776 kB/s
# regardless of NANDC clock (time-based, not clock-based).
#
# Fix: redirect the 4 'bl usleep_range' sites to a new C helper
# rk_ftl_udelay() (busy-wait udelay, no timer dependency). Blob already
# uses arm_delay_ops (udelay) elsewhere, so busy-waiting is the vendor's
# own idiom on this SoC. Idempotent via symbol presence.
import io

BLK = "/vol/kernel-src/drivers/rk_nand/rk_ftlv5_arm32.S"
BASE = "/vol/kernel-src/drivers/rk_nand/rk_nand_base.c"

# --- 1. patch blob call sites ---
with io.open(BLK, "r", encoding="utf-8", errors="replace") as f:
    s = f.read()
n_sleep = s.count("bl\tusleep_range")
n_new = s.count("bl\trk_ftl_udelay")
if n_sleep == 0 and n_new >= 4:
    print("BLOB: already patched (%d sites)" % n_new)
else:
    assert n_sleep == 4, "expected 4 usleep_range sites, got %d" % n_sleep
    s = s.replace("bl\tusleep_range", "bl\trk_ftl_udelay")
    with io.open(BLK, "w", encoding="utf-8", newline="") as f:
        f.write(s)
    print("BLOB: 4 usleep_range sites -> rk_ftl_udelay")

# --- 2. add helper to base.c ---
with io.open(BASE, "r", encoding="utf-8", errors="replace") as f:
    b = f.read()
if "rk_ftl_udelay" in b:
    print("BASE: helper already present")
    raise SystemExit(0)

assert "#include <linux/delay.h>" in b or True
if "#include <linux/delay.h>" not in b:
    anchor = "#include <linux/clk.h>\n"
    assert b.count(anchor) == 1, "clk include anchor x%d" % b.count(anchor)
    b = b.replace(anchor, anchor + "#include <linux/delay.h>\n")

anchor2 = "int rknand_get_clk_rate(int nandc_id)\n"
assert b.count(anchor2) == 1, "clk_rate anchor x%d" % b.count(anchor2)
helper = (
    "/* V17.2: busy-wait usleep replacement for ftlv5 blob (no HR timers). */\n"
    "void rk_ftl_udelay(unsigned long us)\n"
    "{\n"
    "\tudelay(us);\n"
    "}\n"
    "EXPORT_SYMBOL(rk_ftl_udelay);\n\n"
)
b = b.replace(anchor2, helper + anchor2)

with io.open(BASE, "w", encoding="utf-8", newline="") as f:
    f.write(b)
print("BASE: rk_ftl_udelay helper added")
