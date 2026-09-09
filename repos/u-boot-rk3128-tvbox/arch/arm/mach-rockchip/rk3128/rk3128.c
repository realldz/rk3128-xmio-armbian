/*
 * Copyright (c) 2017 Rockchip Electronics Co., Ltd
 *
 * SPDX-License-Identifier:     GPL-2.0+
 */
#include <asm/io.h>
#include <asm/arch/hardware.h>
#include <asm/arch/bootrom.h>
#include <asm/arch/grf_rk3128.h>

#define GRF_GPIO1C_IOMUX		0x200080c0
#define SDMMC_INTMASK			0x10214024
#define READLATENCY_VAL			0x3f
#define BUS_MSCH_QOS_BASE		0x10128014
#define	CPU_AXI_QOS_PRIORITY_BASE	0x1012f188
#define CPU_AXI_QOS_PRIORITY_LEVEL(h, l) \
	((((h) & 3) << 8) | (((h) & 3) << 2) | ((l) & 3))
#define	CPU_AXI_CIF_QOS_PRIORITY_BASE	0x1012f208

int arch_cpu_init(void)
{
	/* We do some SoC one time setting here. */

	/* Read latency configure */
	writel(READLATENCY_VAL, BUS_MSCH_QOS_BASE);

	/* Set lcdc cpu axi qos priority level */
	writel(CPU_AXI_QOS_PRIORITY_LEVEL(3, 3), CPU_AXI_QOS_PRIORITY_BASE);

	/* Set GPIO1_C1 iomux to gpio, default sdcard_detn */
	writel(0x00040000, GRF_GPIO1C_IOMUX);

#ifdef CONFIG_ROCKCHIP_RK3126
	/*
	 * Disable interrupt, otherwise it always generates wakeup signal. This
	 * is an IC hardware issue.
	 */
	writel(0, SDMMC_INTMASK);

	/* raise cif ddr qos priority */
	writel(CPU_AXI_QOS_PRIORITY_LEVEL(3, 3), CPU_AXI_CIF_QOS_PRIORITY_BASE);
#endif

	return 0;
}

void board_debug_uart_init(void)
{
	struct rk3128_grf * const grf __maybe_unused =
		(struct rk3128_grf * const)0x20008000;

	/*
	 * Early debug UART runs before the normal pinctrl / stdout-path flow,
	 * so select the mux from CONFIG_DEBUG_UART_BASE.
	 */
#if defined(CONFIG_DEBUG_UART_BASE) && (CONFIG_DEBUG_UART_BASE == 0x20064000)
	rk_clrsetreg(&grf->gpio1b_iomux,
		     GPIO1B1_MASK | GPIO1B2_MASK,
		     GPIO1B1_UART1_SOUT << GPIO1B1_SHIFT |
		     GPIO1B2_UART1_SIN << GPIO1B2_SHIFT);
#else
	rk_clrsetreg(&grf->gpio1c_iomux,
		     GPIO1C2_MASK | GPIO1C3_MASK,
		     GPIO1C2_UART2_TX << GPIO1C2_SHIFT |
		     GPIO1C3_UART2_RX << GPIO1C3_SHIFT);
#endif
}
