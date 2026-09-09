#!/usr/bin/env python3
# v17-dts.py — add timer channel 2 @0x20044020 as clocksource+sched_clock.
# Root cause: DTB had a single timer node (timer@20044000) -> driver used it
# as clockevent only; rk_clksrc_init() never ran -> no clocksource, no
# sched_clock -> kernel time granularity = jiffies (10ms): dmesg stamps all
# .000000, ping/mtr rounding to 10ms steps.
# Channel layout mirrors RK3288: 0x20-stride from 0x20044000, IRQs SPI28/29
# (0x1c/0x1d). Clocksource path never requests an IRQ (only clkevt does),
# so the mapped-but-unused SPI is safe: if ch2 does not exist in HW, probe
# fails cleanly and system stays on the current jiffies fallback.
import sys

src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as f:
    s = f.read()

if "timer@20044020" in s:
    with open(dst, "w", encoding="utf-8", newline="") as f:
        f.write(s)
    print("V17_DTS_OK: already has timer@20044020")
    raise SystemExit(0)

i = s.index("\ttimer@20044000 {")
j = s.index("\t};\n", i) + len("\t};\n")
blk = s[i:j]

def line(name):
    for l in blk.splitlines():
        if l.strip().startswith(name):
            return l
    raise AssertionError(name + " not found in existing timer node")

node = (
    "\ttimer@20044020 {\n"
    '\t\tcompatible = "rockchip,rk3128-timer\\0rockchip,rk3288-timer";\n'
    "\t\treg = <0x20044020 0x20>;\n"
    "\t\tinterrupts = <0x00 0x1d 0x04>;\n"
    + line("clocks =") + "\n"
    + line("clock-names =") + "\n"
    + '\t\tstatus = "okay";\n'
    "\t};\n"
)
s = s[:j] + node + s[j:]

with open(dst, "w", encoding="utf-8", newline="") as f:
    f.write(s)
print("V17_DTS_OK: timer@20044020 inserted after timer@20044000")
