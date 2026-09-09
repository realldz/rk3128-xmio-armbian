/*
 * RK3128 storage mux helpers for boards populated with either NAND or eMMC
 * on the same shared pin group.
 *
 * SPDX-License-Identifier: GPL-2.0+
 */

#include <common.h>
#include <asm/io.h>
#include <asm/arch/grf_rk3128.h>
#include <asm/arch/hardware.h>
#include <asm/arch/rk3128_storage.h>

#define RK3128_GRF_BASE			0x20008000
#define RK3128_NANDC_BASE		0x10500000

#define NANDC_V6_DEF_TIMEOUT		20000

#define NANDC_REG_V6_FMCTL		0x00
#define NANDC_REG_V6_FMWAIT		0x04
#define NANDC_REG_V6_BCHCTL		0x0c
#define NANDC_REG_V6_DMA_CFG		0x10
#define NANDC_REG_V6_RANDMZ		0x150
#define NANDC_REG_V6_BANK0		0x800

#define NANDC_REG_V6_ADDR		0x04
#define NANDC_REG_V6_CMD		0x08

#define NANDC_V6_FM_WP			BIT(8)
#define NANDC_V6_FM_FREADY		BIT(9)

static int rk3128_nand_presence = -1;

static inline struct rk3128_grf *rk3128_grf_get(void)
{
	return (struct rk3128_grf *)RK3128_GRF_BASE;
}

static void rk3128_nand_select_chip(void __iomem *regs, int chipnr)
{
	u32 reg = NANDC_V6_FM_WP;

	if (chipnr >= 0)
		reg |= BIT(chipnr);

	writel(reg, regs + NANDC_REG_V6_FMCTL);
}

static bool rk3128_nand_wait_ready(void __iomem *regs)
{
	int timeout = NANDC_V6_DEF_TIMEOUT;

	while (timeout--) {
		if (readl(regs + NANDC_REG_V6_FMCTL) & NANDC_V6_FM_FREADY)
			return true;
		udelay(1);
	}

	return false;
}

static void rk3128_nand_hw_init(void __iomem *regs)
{
	writel(0, regs + NANDC_REG_V6_RANDMZ);
	writel(0, regs + NANDC_REG_V6_DMA_CFG);
	writel(0, regs + NANDC_REG_V6_BCHCTL);
	writel(NANDC_V6_FM_WP, regs + NANDC_REG_V6_FMCTL);
	writel(0x1081, regs + NANDC_REG_V6_FMWAIT);
}

static bool rk3128_nand_id_valid(const u8 *id)
{
	if (id[0] == 0x00 || id[0] == 0xff)
		return false;
	if (id[1] == 0x00 || id[1] == 0xff)
		return false;

	return id[0] != id[1];
}

static bool rk3128_nand_read_id(u8 *id)
{
	void __iomem *regs = (void __iomem *)RK3128_NANDC_BASE;
	void __iomem *bank_base = regs + NANDC_REG_V6_BANK0;
	int i;

	rk3128_nand_hw_init(regs);
	rk3128_nand_select_chip(regs, 0);

	if (!rk3128_nand_wait_ready(regs))
		goto out;

	writeb(0xff, bank_base + NANDC_REG_V6_CMD);
	if (!rk3128_nand_wait_ready(regs))
		goto out;

	writeb(0x90, bank_base + NANDC_REG_V6_CMD);
	writeb(0x00, bank_base + NANDC_REG_V6_ADDR);
	udelay(1);

	for (i = 0; i < 5; i++)
		id[i] = readb(bank_base);

out:
	rk3128_nand_select_chip(regs, -1);

	return rk3128_nand_id_valid(id);
}

void rk3128_configure_nand_pins(void)
{
	struct rk3128_grf *grf = rk3128_grf_get();

	rk_clrsetreg(&grf->gpio1d_iomux,
		     GPIO1D0_MASK | GPIO1D1_MASK | GPIO1D2_MASK |
		     GPIO1D3_MASK | GPIO1D4_MASK | GPIO1D5_MASK |
		     GPIO1D6_MASK | GPIO1D7_MASK,
		     GPIO1D0_NAND_D0 << GPIO1D0_SHIFT |
		     GPIO1D1_NAND_D1 << GPIO1D1_SHIFT |
		     GPIO1D2_NAND_D2 << GPIO1D2_SHIFT |
		     GPIO1D3_NAND_D3 << GPIO1D3_SHIFT |
		     GPIO1D4_NAND_D4 << GPIO1D4_SHIFT |
		     GPIO1D5_NAND_D5 << GPIO1D5_SHIFT |
		     GPIO1D6_NAND_D6 << GPIO1D6_SHIFT |
		     GPIO1D7_NAND_D7 << GPIO1D7_SHIFT);

	rk_clrsetreg(&grf->gpio2a_iomux,
		     GPIO2A0_MASK | GPIO2A1_MASK | GPIO2A2_MASK |
		     GPIO2A3_MASK | GPIO2A4_MASK | GPIO2A5_MASK |
		     GPIO2A6_MASK | GPIO2A7_MASK,
		     GPIO2A0_NAND_ALE << GPIO2A0_SHIFT |
		     GPIO2A1_NAND_CLE << GPIO2A1_SHIFT |
		     GPIO2A2_NAND_WRN << GPIO2A2_SHIFT |
		     GPIO2A3_NAND_RDN << GPIO2A3_SHIFT |
		     GPIO2A4_NAND_RDY << GPIO2A4_SHIFT |
		     GPIO2A5_NAND_WP << GPIO2A5_SHIFT |
		     GPIO2A6_NAND_CS0 << GPIO2A6_SHIFT |
		     GPIO2A7_NAND_DQS << GPIO2A7_SHIFT);
}

void rk3128_configure_emmc_pins(void)
{
	struct rk3128_grf *grf = rk3128_grf_get();

	rk_clrsetreg(&grf->gpio1c_iomux,
		     GPIO1C6_MASK,
		     GPIO1C6_EMMC_CMD << GPIO1C6_SHIFT);

	rk_clrsetreg(&grf->gpio1d_iomux,
		     GPIO1D0_MASK | GPIO1D1_MASK | GPIO1D2_MASK |
		     GPIO1D3_MASK | GPIO1D4_MASK | GPIO1D5_MASK |
		     GPIO1D6_MASK | GPIO1D7_MASK,
		     GPIO1D0_EMMC_D0 << GPIO1D0_SHIFT |
		     GPIO1D1_EMMC_D1 << GPIO1D1_SHIFT |
		     GPIO1D2_EMMC_D2 << GPIO1D2_SHIFT |
		     GPIO1D3_EMMC_D3 << GPIO1D3_SHIFT |
		     GPIO1D4_EMMC_D4 << GPIO1D4_SHIFT |
		     GPIO1D5_EMMC_D5 << GPIO1D5_SHIFT |
		     GPIO1D6_EMMC_D6 << GPIO1D6_SHIFT |
		     GPIO1D7_EMMC_D7 << GPIO1D7_SHIFT);

	rk_clrsetreg(&grf->gpio2a_iomux,
		     GPIO2A0_MASK | GPIO2A1_MASK | GPIO2A2_MASK |
		     GPIO2A3_MASK | GPIO2A4_MASK | GPIO2A5_MASK |
		     GPIO2A6_MASK | GPIO2A7_MASK,
		     GPIO2A0_GPIO << GPIO2A0_SHIFT |
		     GPIO2A1_GPIO << GPIO2A1_SHIFT |
		     GPIO2A2_GPIO << GPIO2A2_SHIFT |
		     GPIO2A3_GPIO << GPIO2A3_SHIFT |
		     GPIO2A4_GPIO << GPIO2A4_SHIFT |
		     GPIO2A5_EMMC_PWREN << GPIO2A5_SHIFT |
		     GPIO2A6_GPIO << GPIO2A6_SHIFT |
		     GPIO2A7_EMMC_CLKOUT << GPIO2A7_SHIFT);
}

bool rk3128_nand_is_present(void)
{
	u8 id[5] = { 0 };

	if (rk3128_nand_presence >= 0)
		return rk3128_nand_presence;

	rk3128_configure_nand_pins();
	if (!rk3128_nand_read_id(id)) {
		rk3128_nand_presence = 0;
		rk3128_configure_emmc_pins();
		debug("rk3128: NAND absent\n");
		return false;
	}

	rk3128_nand_presence = 1;
	debug("rk3128: NAND ID %02x %02x %02x %02x %02x\n",
	      id[0], id[1], id[2], id[3], id[4]);

	return true;
}
