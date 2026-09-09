#!/usr/bin/env python3
# v15-release.py — strip ALL periodic diag instrumentation from the v14
# sources, keep every functional fix, silence boot-time noise.
#
# KEEPS (functional):
#   - PERIODIC-only clockevent + HZ_PERIODIC config (proven stable)
#   - clk_disable_unused made a silent no-op (walks tree, gates nothing)
#   - rockchip_pd_keepon_do_release early-return (domains stay ALWAYS_ON)
#   - rknand background GC off (rk_ftl_gc_do = 0)
#   - v9 arch-timer skip logic, v10 SIP guard (untouched, in other files)
#   - one-shot boot prints V9DIAG (clkevt/clksrc registered)
# REMOVES (noise):
#   - V13DIAG hb kthread + V13HB direct-UART emitter + v14 counters
#   - V13DIAG set_next_event tripwire
#   - V12DIAG rq/gc prints + counters
#   - V14PDIAG prints, V14CLK prints
#   - parameter.txt: initcall_debug / ignore_loglevel / rootdelay=60
import io
import sys

TS = sys.argv[1] if len(sys.argv) > 1 else "/vol/kernel-src"


def load(p):
    with io.open(TS + "/" + p, "r", encoding="utf-8") as f:
        return f.read()


def save(p, s):
    with io.open(TS + "/" + p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def rep1(s, old, new):
    n = s.count(old)
    assert n == 1, "anchor x%d: %r" % (n, old[:70])
    return s.replace(old, new)


# ---------------------------------------------------------------- timer
p = "drivers/clocksource/timer-rockchip.c"
s = load(p)
if "V15RELEASE_MARKER" not in s:
    # 1. tripwire in set_next_event
    s = rep1(
        s,
        "\tpr_warn_once(\"V13DIAG: set_next_event cycles=%lu "
        "(oneshot requested!)\\n\", (unsigned long)cycles); "
        "/* V13DIAG tripwire */\n",
        "")
    # 2. V14 declarations + direct-UART emitter block
    s = rep1(
        s,
        "/* V14_FWD_MARKER */\n"
        "static unsigned long v13_ticks;\n"
        "static unsigned int v14_irq_cnt[4];\n"
        "static bool v14_tick_dead;\n"
        "static char v14_hb_buf[96];\n"
        "static void __iomem *v14_uart0_base;\n"
        "\n"
        "/* direct UART0 emit, bypasses printk entirely (8250 MMIO32,\n"
        " * reg-shift 2: THR @0x00, LSR @0x14, THRE=BIT(5)) */\n"
        "static void v14_uart_puts(const char *s)\n"
        "{\n"
        "\tif (!v14_uart0_base)\n"
        "\t\treturn;\n"
        "\twhile (*s) {\n"
        "\t\twhile (!(readl_relaxed(v14_uart0_base + 0x14) & 0x20))\n"
        "\t\t\tcpu_relax();\n"
        "\t\twritel(*s++, v14_uart0_base);\n"
        "\t}\n"
        "}\n"
        "\n",
        "")
    # 3. IRQ handler counters + online-collapse report
    s = rep1(
        s,
        "\tstruct clock_event_device *ce = dev_id;\n"
        "\tunsigned int v14_cpu = smp_processor_id();\n"
        "\tstruct rk_timer *timer = rk_timer(ce);\n"
        "\n"
        "\t/* V14_IRQCNT_MARKER */\n"
        "\tif (v14_cpu < 4)\n"
        "\t\tv14_irq_cnt[v14_cpu]++;\n"
        "\n"
        "\trk_timer_interrupt_clear(timer);\n",
        "\tstruct clock_event_device *ce = dev_id;\n"
        "\tstruct rk_timer *timer = rk_timer(ce);\n"
        "\n"
        "\trk_timer_interrupt_clear(timer);\n")
    s = rep1(
        s,
        "\tif (num_online_cpus() == 1 && !v14_tick_dead) {\n"
        "\t\tv14_tick_dead = true;\n"
        "\t\tpr_emerg(\"V14DEAD: online=1 irq=%u,%u,%u,%u\\n\",\n"
        "\t\t\t v14_irq_cnt[0], v14_irq_cnt[1], v14_irq_cnt[2],\n"
        "\t\t\t v14_irq_cnt[3]);\n"
        "\t}\n"
        "\tce->event_handler(ce);\n",
        "\tce->event_handler(ce);\n")
    # 4. heartbeat thread + starter
    s = rep1(
        s,
        "/* V13DIAG: heartbeat - is the tick alive after userspace starts? */\n"
        "static int v13_hb_thread(void *arg)\n"
        "{\n"
        "\tstatic unsigned long v13_last;\n"
        "\tstatic unsigned long v13_last_ticks;\n"
        "\tunsigned long delta, evts;\n"
        "\tunsigned int ctrl, cur, load, intst;\n"
        "\n"
        "\t(void)arg;\n"
        "\tv13_last = jiffies;\n"
        "\tv13_last_ticks = v13_ticks;\n"
        "\twhile (!kthread_should_stop()) {\n"
        "\t\tset_current_state(TASK_INTERRUPTIBLE);\n"
        "\t\tschedule_timeout(5 * HZ);\n"
        "\t\tif (!rk_clkevt)\n"
        "\t\t\tbreak;\n"
        "\t\tctrl = readl_relaxed(rk_clkevt->timer.base + "
        "TIMER_CONTROL_REG3288);\n"
        "\t\tcur = readl_relaxed(rk_clkevt->timer.base + "
        "TIMER_CURRENT_VALUE0);\n"
        "\t\tload = readl_relaxed(rk_clkevt->timer.base + "
        "TIMER_LOAD_COUNT0);\n"
        "\t\tintst = readl_relaxed(rk_clkevt->timer.base + "
        "TIMER_INT_STATUS);\n"
        "\t\tdelta = jiffies - v13_last;\n"
        "\t\tevts = v13_ticks - v13_last_ticks;\n"
        "\t\tv13_last = jiffies;\n"
        "\t\tv13_last_ticks = v13_ticks;\n"
        "\t\tif (delta > 6 && !v14_tick_dead) {\n"
        "\t\t\tv14_tick_dead = true;\n"
        "\t\t\tpr_emerg(\"V14DEAD: tick frozen! delta=%lu evts=%lu\\n\",\n"
        "\t\t\t\t delta, evts);\n"
        "\t\t}\n"
        "\t\tpr_info(\"V13DIAG: hb jiffies=%lu delta=%lu ctrl=%08x "
        "cur=%08x load=%08x intst=%08x ce_periodic=%d evts=%lu\\n\",\n"
        "\t\t\tjiffies, delta, ctrl, cur, load, intst,\n"
        "\t\t\t(int)clockevent_state_periodic(&rk_clkevt->ce), evts);\n"
        "\t\tsnprintf(v14_hb_buf, sizeof(v14_hb_buf),\n"
        "\t\t\t \"V13HB: j=%lu d=%lu ev=%lu irq=%u,%u,%u,%u\\n\",\n"
        "\t\t\t jiffies, delta, evts,\n"
        "\t\t\t v14_irq_cnt[0], v14_irq_cnt[1], v14_irq_cnt[2],\n"
        "\t\t\t v14_irq_cnt[3]);\n"
        "\t\tv14_uart_puts(v14_hb_buf);\n"
        "\t}\n"
        "\treturn 0;\n"
        "}\n"
        "\n"
        "static int __init v13_hb_start(void)\n"
        "{\n"
        "\tif (IS_ERR_OR_NULL(rk_clkevt))\n"
        "\t\treturn 0;\n"
        "\t/* V14_UARTMAP_MARKER: direct access to UART0 console hw */\n"
        "\tv14_uart0_base = ioremap(0x20060000, 0x100);\n"
        "\tkthread_run(v13_hb_thread, NULL, \"v13hb\"); "
        "/* V13DIAG heartbeat (early_initcall: kthreadd exists) */\n"
        "\treturn 0;\n"
        "}\n"
        "early_initcall(v13_hb_start);\n"
        "\n",
        "")
    # 5. features comment cleanup
    s = rep1(
        s,
        "\tce->features = CLOCK_EVT_FEAT_PERIODIC | "
        "CLOCK_EVT_FEAT_DYNIRQ; /* V13DIAG: periodic-only, no reprogram "
        "race */\n",
        "\tce->features = CLOCK_EVT_FEAT_PERIODIC | "
        "CLOCK_EVT_FEAT_DYNIRQ;\n")
    s = s.replace("V15RELEASE_MARKER", "")
    s = rep1(s, "#include <linux/kthread.h> /* V13DIAG */\n",
             "/* V15RELEASE_MARKER */\n")
    print("OK   timer: diag stripped, functional fixes kept")
save(p, s)

# ---------------------------------------------------------- nand blk
p = "drivers/rk_nand/rk_nand_blk.c"
s = load(p)
if "V15RELEASE_MARKER" not in s:
    s = rep1(s,
             "static unsigned int v12_rq_count;\n"
             "static unsigned int v12_gc_count;\n",
             "")
    s = rep1(s,
             "\t\trknand_device_lock();\n"
             "\t\tif (v12_rq_count < 8)\n"
             "\t\t\tpr_warn(\"V12DIAG: rq start dev=%s sec=%llu "
             "nsec=%u\\n\",\n"
             "\t\t\t\treq->q->disk ? req->q->disk->disk_name : \"?\",\n"
             "\t\t\t\t(unsigned long long)blk_rq_pos(req),\n"
             "\t\t\t\tblk_rq_sectors(req));\n"
             "\t\tres = do_blktrans_all_request(req);\n"
             "\t\tif (v12_rq_count < 8)\n"
             "\t\t\tpr_warn(\"V12DIAG: rq done res=%d\\n\", (int)res);\n"
             "\t\tv12_rq_count++;\n"
             "\t\trknand_device_unlock();\n",
             "\t\trknand_device_lock();\n"
             "\t\tres = do_blktrans_all_request(req);\n"
             "\t\trknand_device_unlock();\n")
    s = rep1(s,
             "\t\t\t\tif (v12_gc_count < 3)\n"
             "\t\t\t\t\tpr_warn(\"V12DIAG: gc enter\\n\");\n"
             "\t\t\t\tftl_gc_status = rk_ftl_garbage_collect(1, 0);\n"
             "\t\t\t\tif (v12_gc_count < 3)\n"
             "\t\t\t\t\tpr_warn(\"V12DIAG: gc done status=%d\\n\",\n"
             "\t\t\t\t\t\tftl_gc_status);\n"
             "\t\t\t\tv12_gc_count++;\n",
             "\t\t\t\tftl_gc_status = rk_ftl_garbage_collect(1, 0);\n")
    s = s.replace("rk_ftl_gc_do = 0; /* V12DIAG: keep bg GC off */",
                  "rk_ftl_gc_do = 0; /* V15RELEASE_MARKER: bg GC off */")
    s = s.replace("rk_ftl_gc_do = 0; /* V12DIAG: no bg GC (blob race) */",
                  "rk_ftl_gc_do = 0; /* bg GC off */")
    print("OK   nand_blk: rq/gc prints removed, GC stays off")
save(p, s)

# ------------------------------------------------------------ pm-domains
p = "drivers/pmdomain/rockchip/pm-domains.c"
s = load(p)
if "V15RELEASE_MARKER" not in s:
    s = rep1(s,
             "\n\tpr_info(\"V14PDIAG: domain '%s' -> power %d\\n\",\n"
             "\t\t(genpd && genpd->name) ? genpd->name : \"?\", "
             "power_on);\n",
             "\n")
    s = rep1(s,
             "\tpr_info(\"V14PDIAG: keepon release disabled by v14\\n\");\n"
             "\treturn;\n",
             "\treturn; /* V15RELEASE_MARKER: keep-on never released */\n")
    print("OK   pm-domains: prints removed, keepon stays disabled")
save(p, s)

# ------------------------------------------------------------------ clk
p = "drivers/clk/clk.c"
s = load(p)
if "V15RELEASE_MARKER" not in s:
    s = rep1(s,
             "\t\t/* V14_CLKOFF_MARKER: log but never gate (culprit-hunt:\n"
             "         * last line before a freeze names the killer "
             "clock) */\n"
             "\t\tpr_info(\"V14CLK: would gate: %s\\n\", core->name);\n",
             "\t\t/* V15RELEASE_MARKER: unused clocks deliberately left "
             "on */\n")
    s = rep1(s,
             "\t\t/* V14_CLKOFF_MARKER */\n"
             "\t\tpr_info(\"V14CLK: would unprepare: %s\\n\", "
             "core->name);\n",
             "\t\t/* V15RELEASE_MARKER: unprepare skipped */\n")
    print("OK   clk: prints removed, gating stays disabled")
save(p, s)

print("V15RELEASE_PATCH_OK")
