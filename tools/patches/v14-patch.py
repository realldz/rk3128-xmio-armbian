#!/usr/bin/env python3
# v14-patch.py — idempotent source patcher for v14 (kernel 6.6.89).
#
# 1. drivers/clocksource/timer-rockchip.c
#    - heartbeat hardening: per-CPU irq counters, event counter, direct
#      UART0 (0x20060000, ioremap) emits "V13HB:" line each 5 s WITHOUT
#      printk -> heartbeat visible even if the console driver is dead;
#      V14DEAD reports on frozen tick (delta>6) or online-cpu collapse.
#    - IRQ handler counts per-CPU irqs.
# 2. drivers/pmdomain/rockchip/pm-domains.c
#    - PRIMARY SUSPECT FIX: rockchip_pd_keepon_do_release (late_initcall
#      _sync ~20.7s) is disabled: keepon_startup domains (PD_VIO in our
#      DTB, PD_MSCH in table) stay GENPD_FLAG_ALWAYS_ON forever -> no
#      power_off_work is ever queued for them.
#    - V14PDIAG: announce every domain power off/on.
# 3. drivers/clk/clk.c
#    - SECONDARY SUSPECT FIX + telemetry: clk_disable_unused logs every
#      clock it WOULD gate/unprepare ("V14CLK: would gate ...") and then
#      actually keeps it enabled. Last V14CLK line before a freeze names
#      the culprit clock.
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

if "V14_HB_MARKER" not in s:
    s = rep1(
        s,
        "/* V13DIAG: heartbeat - is the tick alive after userspace starts? */\n",
        "/* V14_HB_MARKER */\n"
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
        "\n"
        "/* V13DIAG: heartbeat - is the tick alive after userspace starts? */\n")
    print("OK   timer: v14 counters + direct-UART emitter")

if "V14_FWD_MARKER" not in s:
    # move the v14 declaration/emitter block above the IRQ handler
    # (it was inserted next to the heartbeat thread, which lives AFTER
    #  rk_timer_interrupt -> 'undeclared' on first build attempt)
    i0 = s.find("/* V14_HB_MARKER */")
    i1 = s.find("/* V13DIAG: heartbeat - is the tick alive after "
                "userspace starts? */", i0)
    assert 0 <= i0 < i1, "marker block not found"
    block = s[i0:i1]
    s = s[:i0] + s[i1:]
    idx = s.find("static irqreturn_t rk_timer_interrupt")
    assert idx > 0
    s = s[:idx] + block + s[idx:]
    s = s.replace("/* V14_HB_MARKER */", "/* V14_FWD_MARKER */", 1)
    print("OK   timer: v14 declarations moved above IRQ handler")

if "V14_UARTMAP_MARKER" not in s:
    s = rep1(
        s,
        "\tif (IS_ERR_OR_NULL(rk_clkevt))\n"
        "\t\treturn 0;\n"
        "\tkthread_run(v13_hb_thread, NULL, \"v13hb\");",
        "\tif (IS_ERR_OR_NULL(rk_clkevt))\n"
        "\t\treturn 0;\n"
        "\t/* V14_UARTMAP_MARKER: direct access to UART0 console hw */\n"
        "\tv14_uart0_base = ioremap(0x20060000, 0x100);\n"
        "\tkthread_run(v13_hb_thread, NULL, \"v13hb\");")
    print("OK   timer: ioremap UART0 in v13_hb_start")

if "unsigned long delta, evts;" not in s:
    s = rep1(s,
             "\tstatic unsigned long v13_last;\n"
             "\tunsigned long delta;\n",
             "\tstatic unsigned long v13_last;\n"
             "\tstatic unsigned long v13_last_ticks;\n"
             "\tunsigned long delta, evts;\n")
    s = rep1(s,
             "\tv13_last = jiffies;\n"
             "\twhile (!kthread_should_stop()) {",
             "\tv13_last = jiffies;\n"
             "\tv13_last_ticks = v13_ticks;\n"
             "\twhile (!kthread_should_stop()) {")
    s = rep1(
        s,
        "\t\tdelta = jiffies - v13_last;\n"
        "\t\tv13_last = jiffies;\n"
        "\t\tpr_info(\"V13DIAG: hb jiffies=%lu delta=%lu ctrl=%08x "
        "cur=%08x load=%08x intst=%08x ce_periodic=%d\\n\",\n"
        "\t\t\tjiffies, delta, ctrl, cur, load, intst,\n"
        "\t\t\t(int)clockevent_state_periodic(&rk_clkevt->ce));\n",
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
        "\t\tv14_uart_puts(v14_hb_buf);\n")
    print("OK   timer: heartbeat evts + V14DEAD + direct-UART line")

if "V14_IRQCNT_MARKER" not in s:
    s = rep1(
        s,
        "\tstruct clock_event_device *ce = dev_id;\n"
        "\tstruct rk_timer *timer = rk_timer(ce);\n",
        "\tstruct clock_event_device *ce = dev_id;\n"
        "\tunsigned int v14_cpu = smp_processor_id();\n"
        "\tstruct rk_timer *timer = rk_timer(ce);\n"
        "\n"
        "\t/* V14_IRQCNT_MARKER */\n"
        "\tif (v14_cpu < 4)\n"
        "\t\tv14_irq_cnt[v14_cpu]++;\n")
    s = rep1(
        s,
        "\tce->event_handler(ce);\n",
        "\tif (num_online_cpus() == 1 && !v14_tick_dead) {\n"
        "\t\tv14_tick_dead = true;\n"
        "\t\tpr_emerg(\"V14DEAD: online=1 irq=%u,%u,%u,%u\\n\",\n"
        "\t\t\t v14_irq_cnt[0], v14_irq_cnt[1], v14_irq_cnt[2],\n"
        "\t\t\t v14_irq_cnt[3]);\n"
        "\t}\n"
        "\tce->event_handler(ce);\n")
    print("OK   timer: per-cpu irq counters + online-collapse report")
save(p, s)

# ------------------------------------------------------------ pm-domains
p = "drivers/pmdomain/rockchip/pm-domains.c"
s = load(p)
changed = False
if "V14_KEEPOFF_MARKER" not in s:
    s = rep1(
        s,
        "static void rockchip_pd_keepon_do_release(void)\n"
        "{\n"
        "\tstruct generic_pm_domain *genpd;\n"
        "\tstruct rockchip_pm_domain *pd;\n"
        "\tint i;\n"
        "\n"
        "\tif (!g_pmu)\n"
        "\t\treturn;\n"
        "\n",
        "static void rockchip_pd_keepon_do_release(void)\n"
        "{\n"
        "\tstruct generic_pm_domain *genpd;\n"
        "\tstruct rockchip_pm_domain *pd;\n"
        "\tint i;\n"
        "\n"
        "\tif (!g_pmu)\n"
        "\t\treturn;\n"
        "\n"
        "\t/* V14_KEEPOFF_MARKER: keep keepon_startup domains on\n"
        " * GENPD_FLAG_ALWAYS_ON forever. Suspected trigger of the 20.7s\n"
        " * silent freeze (PD_VIO has keepon=true and IS instantiated;\n"
        " * this late_initcall_sync cleared its flag and queued\n"
        " * power_off_work). Never release. */\n"
        "\tpr_info(\"V14PDIAG: keepon release disabled by v14\\n\");\n"
        "\treturn;\n"
        "\n")
    changed = True
    print("OK   pm-domains: keepon release disabled (domains stay on)")
if "V14PDIAG: domain" not in s:
    s = rep1(
        s,
        "\tstruct generic_pm_domain *genpd = &pd->genpd;\n"
        "\n"
        "\tif (pm_domain_always_on && !power_on)\n",
        "\tstruct generic_pm_domain *genpd = &pd->genpd;\n"
        "\n"
        "\tpr_info(\"V14PDIAG: domain '%s' -> power %d\\n\",\n"
        "\t\t(genpd && genpd->name) ? genpd->name : \"?\", power_on);\n"
        "\n"
        "\tif (pm_domain_always_on && !power_on)\n")
    changed = True
    print("OK   pm-domains: V14PDIAG power announcements")
if changed:
    save(p, s)

# ------------------------------------------------------------------ clk
p = "drivers/clk/clk.c"
s = load(p)
if "V14_CLKOFF_MARKER" not in s:
    s = rep1(
        s,
        "\t\ttrace_clk_disable(core);\n"
        "\t\tif (core->ops->disable_unused)\n"
        "\t\t\tcore->ops->disable_unused(core->hw);\n"
        "\t\telse if (core->ops->disable)\n"
        "\t\t\tcore->ops->disable(core->hw);\n"
        "\t\ttrace_clk_disable_complete(core);\n",
        "\t\t/* V14_CLKOFF_MARKER: log but never gate (culprit-hunt:\n"
        "         * last line before a freeze names the killer clock) */\n"
        "\t\tpr_info(\"V14CLK: would gate: %s\\n\", core->name);\n")
    s = rep1(
        s,
        "\t\ttrace_clk_unprepare(core);\n"
        "\t\tif (core->ops->unprepare_unused)\n"
        "\t\t\tcore->ops->unprepare_unused(core->hw);\n"
        "\t\telse if (core->ops->unprepare)\n"
        "\t\t\tcore->ops->unprepare(core->hw);\n"
        "\t\ttrace_clk_unprepare_complete(core);\n",
        "\t\t/* V14_CLKOFF_MARKER */\n"
        "\t\tpr_info(\"V14CLK: would unprepare: %s\\n\", core->name);\n")
    save(p, s)
    print("OK   clk: unused clocks logged and kept alive")

print("V14_SRC_PATCH_OK")
