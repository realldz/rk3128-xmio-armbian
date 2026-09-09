#!/usr/bin/env python3
# v10-patch.py — Plan B v10:
#   (1) stub every SIP SMC (stock chain has no ATF/secure monitor; v9 died at
#       SIP_SHARE_MEM 0x82000009 inside rockchip_gem_get_ddr_info)
#   (2) remove arch/arm/Makefile `ifndef CONFIG_ARM_PSCI` guard so mach-rockchip
#       (rockchip.o + headsmp.o + platsmp.o) actually builds -> SMP via
#       enable-method "rockchip,rk3036-smp" (bootrom mailbox, no PMU needed)
#   (3) shrink v9diag busywait 40M -> 8M iterations
#   (4) light platsmp/rockchip machine logs
# Idempotent; run AFTER v9-patch.py.
import os, sys

K = sys.argv[1] if len(sys.argv) > 1 else "/vol/kernel-src"
applied, skipped = [], []

def patch(rel, old, new, tag, count=1, skip_if_new_in_src=True):
    p = os.path.join(K, rel)
    src = open(p, encoding="utf-8", newline="").read()
    if skip_if_new_in_src and new in src:
        skipped.append(tag); return
    if old not in src:
        skipped.append(tag + " [old absent -> already applied]"); return
    n = src.count(old)
    if n != count:
        sys.exit(f"FATAL anchor {tag!r} in {rel}: found {n}x (expected {count})\n---\n{old}")
    open(p, "w", encoding="utf-8", newline="").write(src.replace(old, new, count))
    applied.append(tag)

T = "\t"

# ---------- (3) v9diag.h: busywait 40M -> 8M ----------
patch("include/linux/v9diag.h",
      "\tfor (i = 0; i < 40000000u; i++)",
      "\tfor (i = 0; i < 8000000u; i++)",
      "v9diag-busywait-8M")

# ---------- (1) rockchip_sip.c: never execute SMC ----------
patch("drivers/firmware/rockchip_sip.c",
      "{\n"
      "\tstruct arm_smccc_res res;\n"
      "\n"
      "\tarm_smccc_smc(function_id, arg0, arg1, arg2, 0, 0, 0, 0, &res);\n"
      "\treturn res;\n"
      "}",
      "{\n"
      "\tstruct arm_smccc_res res;\n"
      "\n"
      "\t/* V10: no ATF/secure monitor on the stock U-Boot 2014.10 chain.\n"
      "\t * Executing SMC traps to Monitor mode through an uninitialized MVBAR\n"
      "\t * and kills the kernel (v9: prefetch abort, __invoke_sip_fn_smc,\n"
      "\t * r0=0x82000009 SIP_SHARE_MEM from rockchip_gem_get_ddr_info).\n"
      "\t * Report every SIP call as unknown-SMC instead. */\n"
      "\tpr_warn(\"V10DIAG: blocked SIP SMC fn=0x%08lx (no ATF on stock chain)\\n\",\n"
      "\t\tfunction_id);\n"
      "\tres.a0 = (unsigned long)SIP_RET_SMC_UNKNOWN;\n"
      "\tres.a1 = 0;\n"
      "\tres.a2 = 0;\n"
      "\tres.a3 = 0;\n"
      "\treturn res;\n"
      "}",
      "sip-stub-no-smc")

# ---------- (2) arch/arm/Makefile: build mach-rockchip ----------
# Note: `new` is a substring that also exists inside the guard, so we must
# key the idempotency check on `old` being absent, not `new` being present.
patch("arch/arm/Makefile",
      "ifndef CONFIG_ARM_PSCI\n"
      "machine-$(CONFIG_ARCH_ROCKCHIP)\t\t+= rockchip\n"
      "endif\n",
      "machine-$(CONFIG_ARCH_ROCKCHIP)\t\t+= rockchip\n",
      "arm-makefile-no-psci-guard",
      skip_if_new_in_src=False)

# ---------- (4) platsmp logs ----------
patch("arch/arm/mach-rockchip/platsmp.c",
      "static void __init rk3036_smp_prepare_cpus(unsigned int max_cpus)\n"
      "{\n"
      "\thas_pmu = false;\n"
      "\n"
      "\trockchip_smp_prepare_cpus(max_cpus);\n"
      "}",
      "static void __init rk3036_smp_prepare_cpus(unsigned int max_cpus)\n"
      "{\n"
      "\thas_pmu = false;\n"
      "\n"
      "\tpr_info(\"V10DIAG: rk3036 smp_prepare_cpus enter\\n\");\n"
      "\trockchip_smp_prepare_cpus(max_cpus);\n"
      "\tpr_info(\"V10DIAG: rk3036 smp_prepare_cpus done ncores=%d\\n\", ncores);\n"
      "}",
      "platsmp-rk3036-prep")

patch("arch/arm/mach-rockchip/platsmp.c",
      "\tfor (i = 1; i < ncores; i++)\n"
      "\t\tpmu_set_power_domain(0 + i, false);\n"
      "}",
      "\tfor (i = 1; i < ncores; i++)\n"
      "\t\tpmu_set_power_domain(0 + i, false);\n"
      "\tpr_info(\"V10DIAG: smp_prepare_cpus done ncores=%d\\n\", ncores);\n"
      "}",
      "platsmp-prep-done")

patch("arch/arm/mach-rockchip/platsmp.c",
      "\t\tpr_err(\"%s: could not map sram registers\\n\", __func__);\n"
      "\t\tof_node_put(node);\n"
      "\t\treturn;\n"
      "\t}\n"
      "\n"
      "\tif (has_pmu && rockchip_smp_prepare_pmu()) {",
      "\t\tpr_err(\"%s: could not map sram registers\\n\", __func__);\n"
      "\t\tof_node_put(node);\n"
      "\t\treturn;\n"
      "\t}\n"
      "\tpr_info(\"V10DIAG: smp sram mapped %px\\n\", sram_base_addr);\n"
      "\n"
      "\tif (has_pmu && rockchip_smp_prepare_pmu()) {",
      "platsmp-sram-mapped")

# ---------- (4) rockchip.c machine-init log ----------
patch("arch/arm/mach-rockchip/rockchip.c",
      "static void __init rockchip_dt_init(void)\n"
      "{\n"
      "\trockchip_suspend_init();",
      "static void __init rockchip_dt_init(void)\n"
      "{\n"
      "\tpr_info(\"V10DIAG: rockchip machine init (mach-rockchip active)\\n\");\n"
      "\trockchip_suspend_init();",
      "rockchip-machine-log")

print("APPLIED:")
for a in applied: print("  +", a)
print("SKIPPED (already present):")
for s in skipped: print("  =", s)
print("V10_PATCH_OK")
