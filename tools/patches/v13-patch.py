#!/usr/bin/env python3
"""v13-patch.py — single-timer SMP tick race mitigation + V13DIAG heartbeat.

Root-cause hypothesis (v12 log + drivers/clocksource/timer-rockchip.c):
  - The DTB exposes exactly ONE timer node -> only rk_clkevt registers
    (no rk_clksrc -> clocksource/sched_clock fall back to jiffies, log:
    "sched_clock: 32 bits at 100 Hz").
  - That single clockevent (cpumask=cpu_possible_mask, ONESHOT capable)
    is installed BOTH as CPU0's local tick device AND as the global
    broadcast device for CPUs 1-3 (their local devices are dummies).
  - In ONESHOT mode the hardware timer is DISABLE+LOAD+ENABLE-reprogrammed
    on every tick and on every idle enter/exit of CPUs 1-3. Broadcast-path
    reprograms take tick_broadcast_lock, but CPU0's own tick_sched
    reprograms run without it -> two CPUs race the same timer registers.
    A lost arming == no more timer IRQ == total freeze. It fires exactly
    when userspace starts forking heavily (udevd) and CPUs begin rapid
    idle churn. Matches v10.1/v11/v12 all dying right after
    "Starting systemd-udevd", with no softlockup/hung_task reports
    (both detectors need a live tick).

Fix: run the tick hard-PERIODIC like the vendor 3.10 kernel did:
  1. clockevent: drop CLOCK_EVT_FEAT_ONESHOT -> auto-reload periodic,
     programmed ONCE, never reprogrammed -> race window gone.
  2. config (planb-v13.sh): HZ_PERIODIC=y, NO_HZ_IDLE=n, HIGH_RES_TIMERS=n.
  3. V13DIAG heartbeat kthread every 5 s: jiffies delta + timer registers
     + clockevent state. Heartbeats stopping while UART works => tick
     died. UART silent but next-boot pstore shows later heartbeats =>
     only the console died.
  4. V13DIAG tripwire in set_next_event (must never fire, periodic-only).

Line-based, idempotent on "V13DIAG".
"""
import io
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "/vol/kernel-src"
TS = SRC + "/drivers/clocksource/timer-rockchip.c"


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
    p = find_one(lines, prev_key)
    for i in range(p + 1, len(lines)):
        if key in lines[i]:
            lines[i] = new_line
            return
    raise SystemExit("FATAL: no %r after %r" % (key, prev_key))


lines = load(TS)
if "V13DIAG" in "".join(lines):
    print("SKIP %s (V13DIAG already present)" % TS)
    sys.exit(0)

# 1. includes for the heartbeat kthread
idx = find_one(lines, "#include <linux/interrupt.h>")
lines[idx + 1:idx + 1] = [
    "#include <linux/kthread.h> /* V13DIAG */\n",
    "#include <linux/sched.h> /* V13DIAG */\n",
    "#include <linux/jiffies.h> /* V13DIAG */\n",
]
print("OK   includes kthread/sched/jiffies")

# 2. drop ONESHOT from the clockevent features (statement spans 2 lines)
idx = find_one(lines, "ce->features = CLOCK_EVT_FEAT_PERIODIC | CLOCK_EVT_FEAT_ONESHOT |")
lines[idx] = ("\tce->features = CLOCK_EVT_FEAT_PERIODIC | CLOCK_EVT_FEAT_DYNIRQ;"
              " /* V13DIAG: periodic-only, no reprogram race */\n")
for i in range(idx + 1, len(lines)):
    if "CLOCK_EVT_FEAT_DYNIRQ;" in lines[i]:
        lines[i] = "\n"
        break
print("OK   features: PERIODIC-only (dropped ONESHOT)")

# 3. tripwire: periodic-only device must never be oneshot-programmed
replace_next_after(
    lines,
    "static inline int rk_timer_set_next_event(unsigned long cycles,",
    "struct rk_timer *timer = rk_timer(ce);",
    "\tstruct rk_timer *timer = rk_timer(ce);\n"
    "\tpr_warn_once(\"V13DIAG: set_next_event cycles=%lu (oneshot requested!)\\n\","
    " (unsigned long)cycles); /* V13DIAG tripwire */\n")
print("OK   set_next_event tripwire")

# 4. heartbeat kthread (insert before rk_clkevt_init)
idx = find_one(lines, "static int __init rk_clkevt_init(struct device_node *np)")
hb = [
    "\n",
    "/* V13DIAG: heartbeat - is the tick alive after userspace starts? */\n",
    "static int v13_hb_thread(void *arg)\n",
    "{\n",
    "\tstatic unsigned long v13_last;\n",
    "\tunsigned long delta;\n",
    "\tunsigned int ctrl, cur, load, intst;\n",
    "\n",
    "\t(void)arg;\n",
    "\tv13_last = jiffies;\n",
    "\twhile (!kthread_should_stop()) {\n",
    "\t\tset_current_state(TASK_INTERRUPTIBLE);\n",
    "\t\tschedule_timeout(5 * HZ);\n",
    "\t\tif (!rk_clkevt)\n",
    "\t\t\tbreak;\n",
    "\t\tctrl = readl_relaxed(rk_clkevt->timer.base + TIMER_CONTROL_REG3288);\n",
    "\t\tcur = readl_relaxed(rk_clkevt->timer.base + TIMER_CURRENT_VALUE0);\n",
    "\t\tload = readl_relaxed(rk_clkevt->timer.base + TIMER_LOAD_COUNT0);\n",
    "\t\tintst = readl_relaxed(rk_clkevt->timer.base + TIMER_INT_STATUS);\n",
    "\t\tdelta = jiffies - v13_last;\n",
    "\t\tv13_last = jiffies;\n",
    "\t\tpr_info(\"V13DIAG: hb jiffies=%lu delta=%lu ctrl=%08x cur=%08x load=%08x intst=%08x ce_periodic=%d\\n\",\n",
    "\t\t\tjiffies, delta, ctrl, cur, load, intst,\n",
    "\t\t\t(int)clockevent_state_periodic(&rk_clkevt->ce));\n",
    "\t}\n",
    "\treturn 0;\n",
    "}\n",
    "\n",
]
lines[idx:idx] = hb
print("OK   heartbeat thread function")

# 5. spawn heartbeat via early_initcall (kthreadd exists; rk_clkevt_init
#    runs from time_init() BEFORE rest_init() -> kthread_run there panics)
idx = find_one(lines, "static int __init rk_clkevt_init(struct device_node *np)")
lines[idx:idx] = [
    "static int __init v13_hb_start(void)\n",
    "{\n",
    "\tif (IS_ERR_OR_NULL(rk_clkevt))\n",
    "\t\treturn 0;\n",
    "\tkthread_run(v13_hb_thread, NULL, \"v13hb\");"
    " /* V13DIAG heartbeat (early_initcall: kthreadd exists) */\n",
    "\treturn 0;\n",
    "}\n",
    "early_initcall(v13_hb_start);\n",
    "\n",
]
print("OK   heartbeat early_initcall spawn")

save(TS, lines)
print("V13_PATCH_OK")
