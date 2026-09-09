#!/usr/bin/env python3
# v9-patch.py — Plan B v9: timer-health instrumentation + CNTVCT auto-bailout.
# Target: /vol/kernel-src (docker). Idempotent: skips already-applied hunks.
import os, sys

K = sys.argv[1] if len(sys.argv) > 1 else "/vol/kernel-src"
applied, skipped = [], []

def patch(rel, old, new, tag, count=1):
    p = os.path.join(K, rel)
    src = open(p, encoding="utf-8", newline="").read()
    if new in src:
        skipped.append(tag); return
    n = src.count(old)
    if n != count:
        sys.exit(f"FATAL anchor {tag!r} in {rel}: found {n}x (expected {count})\n---\n{old}")
    open(p, "w", encoding="utf-8", newline="").write(src.replace(old, new, count))
    applied.append(tag)

def write(rel, content):
    p = os.path.join(K, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w", encoding="utf-8", newline="").write(content)
    applied.append(f"WRITE {rel}")

T = "\t"  # tab

# ---------- include/linux/v9diag.h ----------
write("include/linux/v9diag.h", f"""/* SPDX-License-Identifier: GPL-2.0 */
/* V9DIAG: RK3128 Plan-B timer-health probe (temporary instrumentation).
 * Measures cp15 CNTVCT, DW timer@0x20044000, jiffies and sched_clock with a
 * busy-wait that does NOT depend on jiffies / delay calibration.
 */
#ifndef _LINUX_V9DIAG_H
#define _LINUX_V9DIAG_H

#include <linux/io.h>
#include <linux/jiffies.h>
#include <linux/printk.h>
#include <linux/sched/clock.h>

#define V9DIAG_TIMER_BASE\t0x20044000
#define V9DIAG_CRU_BASE\t\t0x20000000

static inline void v9diag_busywait(void)
{{
\tvolatile unsigned int i;

\tfor (i = 0; i < 40000000u; i++)
\t\t;
}}

static inline void v9diag_timer_health(const char *tag)
{{
\tunsigned long js1, js2;
\tunsigned long long c1, c2, sc1, sc2;
\tu32 cntfrq, ctrl, t1 = 0, t2 = 0, g10a, g10b;
\tint i;
\tvoid __iomem *tk, *cr;

\tasm volatile("mrc p15, 0, %0, c14, c0, 0" : "=r"(cntfrq));
\tasm volatile("mrrc p15, 1, %Q0, %R0, c14" : "=r"(c1));

\ttk = ioremap(V9DIAG_TIMER_BASE, 0x20);
\tif (tk) {{
\t\tctrl = readl(tk + 0x10);
\t\twritel(ctrl | 0x1, tk + 0x10);/* keep mode, ensure enabled */
\t\tt1 = readl(tk + 0x08);
\t}}
\tcr = ioremap(V9DIAG_CRU_BASE, 0x200);
\tif (cr) {{
\t\tg10a = readl(cr + 0xf8);
\t\t/* open SCLK_TIMER0..5 gates (CON10 bits 3..8, write-enable high half) */
\t\twritel(0x01f80000u, cr + 0xf8);
\t\tg10b = readl(cr + 0xf8);
\t\tfor (i = 0; i < 5; i++)
\t\t\tpr_info("V9DIAG[%s]: CRU gate %02d: %08x %08x %08x\\n", tag,
\t\t\t\ti, readl(cr + 0xd0 + 4 * i), readl(cr + 0xe4 + 4 * i),
\t\t\t\treadl(cr + 0xf8 + 4 * i));
\t}}

\tjs1 = jiffies;
\tsc1 = sched_clock();
\tv9diag_busywait();
\tasm volatile("mrrc p15, 1, %Q0, %R0, c14" : "=r"(c2));
\tif (tk)
\t\tt2 = readl(tk + 0x08);
\tjs2 = jiffies;
\tsc2 = sched_clock();

\tpr_info("V9DIAG[%s]: CNTFRQ=%u CNTVCT %llu -> %llu (%s) DW-TIMER %08x -> %08x (%s) jiffies %lu -> %lu (%s) sched_clock %llu -> %llu (%s)\\n",
\t\ttag, cntfrq,
\t\tc1, c2, (c2 != c1) ? "TICKING" : "FROZEN",
\t\tt1, t2, (t2 != t1) ? "TICKING" : "FROZEN",
\t\tjs1, js2, (js2 != js1) ? "TICKING" : "FROZEN",
\t\tsc1, sc2, (sc2 != sc1) ? "TICKING" : "FROZEN");
\tpr_info("V9DIAG[%s]: CRU CON10 %08x -> %08x (timer gates; bit set=gated OFF)\\n",
\t\ttag, g10a, g10b);

\tif (tk) {{
\t\twritel(ctrl, tk + 0x10);/* restore exact mode */
\t\tiounmap(tk);
\t}}
\tif (cr)
\t\tiounmap(cr);
}}

#endif /* _LINUX_V9DIAG_H */
""")

# ---------- 8250_dw.c ----------
F = "drivers/tty/serial/8250/8250_dw.c"
patch(F, f"""#include "8250_dwlib.h"
""", f"""#include "8250_dwlib.h"
#include <linux/v9diag.h>
""", "dw-include")

patch(F, f"""{T}struct dw8250_data *data;
{T}struct resource *regs;
""", f"""{T}struct dw8250_data *data;
{T}static int v9diag_once;
{T}struct resource *regs;
""", "dw-decl")

patch(F, f"""{T}int err;

{T}regs = platform_get_resource(pdev, IORESOURCE_MEM, 0);
""", f"""{T}int err;

{T}pr_info("V9DIAG: dw8250_probe enter\\n");
{T}if (!v9diag_once)
{T}{T}v9diag_timer_health("probe-entry");
{T}v9diag_once = 1;

{T}regs = platform_get_resource(pdev, IORESOURCE_MEM, 0);
""", "dw-entry")

patch(F, f"""{T}err = uart_read_port_properties(p);
{T}/* no interrupt -> fall back to polling */
""", f"""{T}pr_info("V9DIAG: dw8250 stage ioremap-ok\\n");
{T}err = uart_read_port_properties(p);
{T}/* no interrupt -> fall back to polling */
""", "dw-s2")

patch(F, f"""{T}INIT_WORK(&data->clk_work, dw8250_clk_work_cb);
""", f"""{T}pr_info("V9DIAG: dw8250 stage clocks-probed\\n");
{T}INIT_WORK(&data->clk_work, dw8250_clk_work_cb);
""", "dw-s3")

patch(F, f"""{T}if (data->clk)
{T}{T}p->uartclk = clk_get_rate(data->clk);
""", f"""{T}if (data->clk)
{T}{T}p->uartclk = clk_get_rate(data->clk);
{T}pr_info("V9DIAG: dw8250 stage uartclk=%u\\n", p->uartclk);
""", "dw-s4")

patch(F, f"""{T}reset_control_deassert(data->rst);
""", f"""{T}reset_control_deassert(data->rst);
{T}pr_info("V9DIAG: dw8250 stage reset-deasserted\\n");
""", "dw-s5")

patch(F, f"""{T}dw8250_quirks(p, data);
""", f"""{T}dw8250_quirks(p, data);
{T}pr_info("V9DIAG: dw8250 stage quirks-done\\n");
""", "dw-s6")

patch(F, f"""{T}if (!data->skip_autocfg)
{T}{T}dw8250_setup_port(p);
""", f"""{T}if (!data->skip_autocfg)
{T}{T}dw8250_setup_port(p);
{T}pr_info("V9DIAG: dw8250 stage setup-port-done\\n");
""", "dw-s7")

patch(F, f"""{T}data->data.line = serial8250_register_8250_port(up);
{T}if (data->data.line < 0)
{T}{T}return data->data.line;
""", f"""{T}pr_info("V9DIAG: dw8250 stage calling-register8250\\n");
{T}data->data.line = serial8250_register_8250_port(up);
{T}if (data->data.line < 0)
{T}{T}return data->data.line;
{T}pr_info("V9DIAG: dw8250 stage register8250-ok line=%d\\n", data->data.line);
""", "dw-s8")

patch(F, f"""{T}if (data->clk) {{
{T}{T}err = clk_notifier_register(data->clk, &data->clk_notifier);
{T}{T}if (err)
{T}{T}{T}return dev_err_probe(dev, err, "Failed to set the clock notifier\\n");
{T}{T}queue_work(system_unbound_wq, &data->clk_work);
{T}}}
""", f"""{T}if (data->clk) {{
{T}{T}err = clk_notifier_register(data->clk, &data->clk_notifier);
{T}{T}if (err)
{T}{T}{T}return dev_err_probe(dev, err, "Failed to set the clock notifier\\n");
{T}{T}queue_work(system_unbound_wq, &data->clk_work);
{T}}}
{T}pr_info("V9DIAG: dw8250 stage notifier-work-queued\\n");
""", "dw-s9")

patch(F, f"""{T}pm_runtime_set_active(dev);
{T}pm_runtime_enable(dev);

{T}return 0;
""", f"""{T}pm_runtime_set_active(dev);
{T}pm_runtime_enable(dev);

{T}pr_info("V9DIAG: dw8250 probe-done\\n");

{T}return 0;
""", "dw-s10")

patch(F, f"""static void
dw8250_do_pm(struct uart_port *port, unsigned int state, unsigned int old)
{{
{T}if (!state)
""", f"""static void
dw8250_do_pm(struct uart_port *port, unsigned int state, unsigned int old)
{{
{T}pr_info("V9DIAG: dw8250_do_pm state=%u\\n", state);
{T}if (!state)
""", "dw-pm")

# ---------- serial_core.c ----------
F = "drivers/tty/serial/serial_core.c"
patch(F, f"""{T}flags = 0;
{T}if (port->flags & UPF_AUTO_IRQ)
""", f"""{T}pr_info("V9DIAG: ucp enter\\n");
{T}flags = 0;
{T}if (port->flags & UPF_AUTO_IRQ)
""", "ucp-enter")

patch(F, f"""{T}{T}port->ops->config_port(port, flags);
{T}{T}if (uart_console(port))
{T}{T}{T}console_unlock();
{T}}}
""", f"""{T}{T}port->ops->config_port(port, flags);
{T}{T}if (uart_console(port))
{T}{T}{T}console_unlock();
{T}}}
{T}pr_info("V9DIAG: ucp config_port-done\\n");
""", "ucp-config")

patch(F, f"""{T}{T}uart_report_port(drv, port);
""", f"""{T}{T}uart_report_port(drv, port);
{T}{T}pr_info("V9DIAG: ucp report-done\\n");
""", "ucp-report")

patch(F, f"""{T}{T}/* Power up port for set_mctrl() */
{T}{T}uart_change_pm(state, UART_PM_STATE_ON);
""", f"""{T}{T}/* Power up port for set_mctrl() */
{T}{T}uart_change_pm(state, UART_PM_STATE_ON);
{T}{T}pr_info("V9DIAG: ucp pm-ON-done\\n");
""", "ucp-pmon")

patch(F, f"""{T}{T}port->mctrl &= TIOCM_DTR;
{T}{T}if (!(port->rs485.flags & SER_RS485_ENABLED))
{T}{T}{T}port->ops->set_mctrl(port, port->mctrl);
{T}{T}spin_unlock_irqrestore(&port->lock, flags);
""", f"""{T}{T}port->mctrl &= TIOCM_DTR;
{T}{T}if (!(port->rs485.flags & SER_RS485_ENABLED))
{T}{T}{T}port->ops->set_mctrl(port, port->mctrl);
{T}{T}spin_unlock_irqrestore(&port->lock, flags);
{T}{T}pr_info("V9DIAG: ucp set_mctrl-done\\n");
""", "ucp-mctrl")

patch(F, f"""{T}{T}uart_rs485_config(port);

{T}{T}if (uart_console(port))
""", f"""{T}{T}uart_rs485_config(port);
{T}{T}pr_info("V9DIAG: ucp rs485-done\\n");

{T}{T}if (uart_console(port))
""", "ucp-rs485")

patch(F, f"""{T}{T}{T}register_console(port->cons);
""", f"""{T}{T}{T}register_console(port->cons);
{T}{T}pr_info("V9DIAG: ucp console-reregister-done\\n");
""", "ucp-cons")

patch(F, f"""{T}{T}if (!uart_console(port))
{T}{T}{T}uart_change_pm(state, UART_PM_STATE_OFF);
{T}}}
""", f"""{T}{T}if (!uart_console(port))
{T}{T}{T}uart_change_pm(state, UART_PM_STATE_OFF);
{T}}}
{T}pr_info("V9DIAG: ucp exit\\n");
""", "ucp-exit")

patch(F, f"""{T}       address, port->irq, port->uartclk / 16, uart_type(port));
""", f"""{T}       address, port->irq, port->uartclk / 16, uart_type(port));

{T}pr_info("V9DIAG: uart_report_port %s banner-printed\\n", port->name);
""", "urp-done")

# ---------- 8250_core.c ----------
F = "drivers/tty/serial/8250/8250_core.c"
patch(F, f"""int serial8250_register_8250_port(const struct uart_8250_port *up)
{{
{T}struct uart_8250_port *uart;
{T}int ret = -ENOSPC;
""", f"""int serial8250_register_8250_port(const struct uart_8250_port *up)
{{
{T}struct uart_8250_port *uart;
{T}int ret = -ENOSPC;

{T}pr_info("V9DIAG: s8250 register-enter uartclk=%u\\n", up->port.uartclk);
""", "s8250-enter")

patch(F, f"""{T}{T}{T}serial8250_apply_quirks(uart);
{T}{T}{T}ret = uart_add_one_port(&serial8250_reg,
{T}{T}{T}{T}{T}{T}&uart->port);
""", f"""{T}{T}{T}serial8250_apply_quirks(uart);
{T}{T}{T}pr_info("V9DIAG: s8250 pre-uart_add_one_port line=%d\\n", uart->port.line);
{T}{T}{T}ret = uart_add_one_port(&serial8250_reg,
{T}{T}{T}{T}{T}{T}&uart->port);
""", "s8250-pre-add")

patch(F, f"""{T}{T}{T}ret = uart->port.line;
""", f"""{T}{T}{T}ret = uart->port.line;
{T}{T}{T}pr_info("V9DIAG: s8250 uart_add_one_port-ok line=%d\\n", ret);
""", "s8250-post-add")

# ---------- serial_port.c ----------
F = "drivers/tty/serial/serial_port.c"
patch(F, f"""int uart_add_one_port(struct uart_driver *drv, struct uart_port *port)
{{
{T}return serial_ctrl_register_port(drv, port);
""", f"""int uart_add_one_port(struct uart_driver *drv, struct uart_port *port)
{{
{T}int ret;

{T}pr_info("V9DIAG: uart_add_one_port enter line=%d type=%d\\n", port->line, port->type);
{T}ret = serial_ctrl_register_port(drv, port);
{T}pr_info("V9DIAG: uart_add_one_port exit ret=%d\\n", ret);

{T}return ret;
""", "uap-wrap")

# ---------- timer-rockchip.c ----------
F = "drivers/clocksource/timer-rockchip.c"
patch(F, f"""{T}clockevents_config_and_register(&rk_clkevt->ce,
{T}{T}{T}{T}{T}rk_clkevt->timer.freq, 1, UINT_MAX);
{T}return 0;
""", f"""{T}clockevents_config_and_register(&rk_clkevt->ce,
{T}{T}{T}{T}{T}rk_clkevt->timer.freq, 1, UINT_MAX);
{T}pr_info("V9DIAG: rk_timer clkevt registered freq=%u\\n", rk_clkevt->timer.freq);
{T}return 0;
""", "rk-clkevt")

patch(F, f"""{T}sched_clock_register(rk_timer_sched_read, 32, rk_clksrc->freq);
{T}return 0;
""", f"""{T}sched_clock_register(rk_timer_sched_read, 32, rk_clksrc->freq);
{T}pr_info("V9DIAG: rk_timer clksrc registered freq=%u\\n", rk_clksrc->freq);
{T}return 0;
""", "rk-clksrc")

# ---------- arm_arch_timer.c ----------
F = "drivers/clocksource/arm_arch_timer.c"
patch(F, f"""static int __init arch_timer_of_init(struct device_node *np)
""", f"""#include <linux/v9diag.h>

static int __init arch_timer_of_init(struct device_node *np)
""", "aat-include")

patch(F, f"""{T}{T}arch_timer_uses_ppi = arch_timer_select_ppi();

{T}if (!arch_timer_ppi[arch_timer_uses_ppi]) {{
""", f"""{T}{T}arch_timer_uses_ppi = arch_timer_select_ppi();

{T}{{
{T}{T}unsigned long long v9c1, v9c2;
{T}{T}asm volatile("mrrc p15, 1, %Q0, %R0, c14" : "=r"(v9c1));
{T}{T}v9diag_busywait();
{T}{T}asm volatile("mrrc p15, 1, %Q0, %R0, c14" : "=r"(v9c2));
{T}{T}pr_info("V9DIAG[timer-of]: CNTFRQ=%u CNTVCT %llu -> %llu (%s)\\n",
{T}{T}{T}rate, v9c1, v9c2, (v9c2 != v9c1) ? "TICKING" : "FROZEN");
{T}{T}if (v9c2 == v9c1) {{
{T}{T}{T}pr_warn("V9DIAG: cp15 counter FROZEN - skipping arm_arch_timer (rk_timer keeps the tick; sched_clock falls back to jiffies)\\n");
{T}{T}{T}return -ENODEV;
{T}{T}}}
{T}}}

{T}if (!arch_timer_ppi[arch_timer_uses_ppi]) {{
""", "aat-bailout")

# ---------- platsmp.c ----------
F = "arch/arm/mach-rockchip/platsmp.c"
patch(F, f"""static int rockchip_boot_secondary(unsigned int cpu, struct task_struct *idle)
{{
{T}int ret;
""", f"""static int rockchip_boot_secondary(unsigned int cpu, struct task_struct *idle)
{{
{T}int ret;

{T}pr_info("V9DIAG: boot_secondary cpu=%u\\n", cpu);
""", "smp-enter")

patch(F, f"""{T}/* start the core */
{T}ret = pmu_set_power_domain(0 + cpu, true);
{T}if (ret < 0)
{T}{T}return ret;
""", f"""{T}/* start the core */
{T}ret = pmu_set_power_domain(0 + cpu, true);
{T}if (ret < 0)
{T}{T}return ret;
{T}pr_info("V9DIAG: boot_secondary cpu=%u power-domain-on\\n", cpu);
""", "smp-pmu")

patch(F, f"""{T}{T}writel(0xDEADBEAF, sram_base_addr + 4);
{T}{T}dsb_sev();
{T}}}

{T}return 0;
""", f"""{T}{T}writel(0xDEADBEAF, sram_base_addr + 4);
{T}{T}dsb_sev();
{T}}}

{T}pr_info("V9DIAG: boot_secondary cpu=%u mailbox+sev-done\\n", cpu);

{T}return 0;
""", "smp-exit")

print("APPLIED:")
for a in applied: print("  +", a)
print("SKIPPED (already present):")
for s in skipped: print("  =", s)
print("V9_PATCH_OK")
