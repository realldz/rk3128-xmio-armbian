/*
 * (C) Copyright 2017 Rockchip Electronics Co., Ltd
 *
 * SPDX-License-Identifier:     GPL-2.0+
 */

#include <common.h>
#include <adc.h>
#include <command.h>
#include <console.h>
#include <dm.h>
#include <asm-generic/gpio.h>
#include <asm/gpio.h>
#include <power/rk8xx_pmic.h>

DECLARE_GLOBAL_DATA_PTR;

#define RK3128_GPIO_WATCH_DEFAULT_MS	10000
#define RK3128_GPIO_WATCH_POLL_MS	10
#define RK3128_ADC_WATCH_DEFAULT_MS	10000
#define RK3128_ADC_WATCH_POLL_MS	20
#define RK3128_SARADC_CHANNELS		3
#define RK3128_MASKROM_ADC_CH		1
#define RK3128_MASKROM_ADC_MAX		30
#define RK3128_MASKROM_SAMPLES		3
#define RK3128_MASKROM_SAMPLE_MS	20

struct rk3128_gpio_watch {
	struct udevice *dev;
	unsigned int gpio;
	unsigned int offset;
	int last;
	char bank_name[8];
};

int board_early_init_r(void)
{
	struct udevice *pmic;
	int ret;

	ret = uclass_first_device_err(UCLASS_PMIC, &pmic);
	if (ret)
		return ret;

	/* Increase USB input current to 2A */
	ret = rk818_spl_configure_usb_input_current(pmic, 2000);
	if (ret)
		return ret;

	return 0;
}

static int rk3128_adc_read_channel(int ch, unsigned int *data)
{
	int ret;

	ret = adc_channel_single_shot("saradc", ch, data);
	if (ret)
		ret = adc_channel_single_shot("adc", ch, data);

	return ret;
}

static int rk3128_maskrom_key_pressed(void)
{
	unsigned int data;
	int i, ret;

	for (i = 0; i < RK3128_MASKROM_SAMPLES; i++) {
		ret = rk3128_adc_read_channel(RK3128_MASKROM_ADC_CH, &data);
		if (ret || data > RK3128_MASKROM_ADC_MAX)
			return 0;
		if (i != RK3128_MASKROM_SAMPLES - 1)
			mdelay(RK3128_MASKROM_SAMPLE_MS);
	}

	return 1;
}

int rk_board_late_init(void)
{
	if (rk3128_maskrom_key_pressed()) {
		puts("Maskrom key held, entering maskrom...\n");
		run_command("rbrom", 0);
	}

	return 0;
}

static void rk3128_gpio_name(char *buf, size_t size,
			     const struct rk3128_gpio_watch *watch)
{
	unsigned int bank = watch->offset / 8;
	unsigned int pin = watch->offset % 8;

	snprintf(buf, size, "%s_%c%d", watch->bank_name, 'A' + bank, pin);
}

static int rk3128_gpio_raw_value(struct udevice *dev, unsigned int offset)
{
	struct dm_gpio_ops *ops = gpio_get_ops(dev);

	if (!ops || !ops->get_value)
		return -1;

	return ops->get_value(dev, offset);
}

static int do_rkgpiowatch(cmd_tbl_t *cmdtp, int flag, int argc,
			  char * const argv[])
{
	struct rk3128_gpio_watch watch[128];
	unsigned int timeout_ms = RK3128_GPIO_WATCH_DEFAULT_MS;
	int bank_filter = -1;
	unsigned long start;
	int count = 0;
	struct udevice *dev;

	if (argc > 3)
		return CMD_RET_USAGE;

	if (argc >= 2)
		timeout_ms = simple_strtoul(argv[1], NULL, 10);
	if (argc == 3)
		bank_filter = simple_strtoul(argv[2], NULL, 10);

	for (uclass_first_device(UCLASS_GPIO, &dev);
	     dev;
	     uclass_next_device(&dev)) {
		struct gpio_dev_priv *uc_priv = dev_get_uclass_priv(dev);
		int offset;
		const char *bank_name;
		int gpio_count;

		if (!uc_priv)
			continue;

		bank_name = gpio_get_bank_info(dev, &gpio_count);
		if (!bank_name || gpio_count <= 0)
			continue;
		if (bank_filter >= 0 &&
		    simple_strtoul(bank_name + 4, NULL, 10) != bank_filter)
			continue;

		for (offset = 0; offset < gpio_count; offset++) {
			int value;

			value = rk3128_gpio_raw_value(dev, offset);
			if (value < 0)
				continue;
			if (count >= ARRAY_SIZE(watch)) {
				printf("rkgpiowatch: watch table full\n");
				goto start_watch;
			}

			watch[count].dev = dev;
			watch[count].gpio = uc_priv->gpio_base + offset;
			watch[count].offset = offset;
			watch[count].last = value;
			strlcpy(watch[count].bank_name, bank_name,
				sizeof(watch[count].bank_name));
			count++;
		}
	}

start_watch:
	if (!count) {
		printf("rkgpiowatch: no GPIO pins currently muxed as GPIO");
		if (bank_filter >= 0)
			printf(" in bank %d", bank_filter);
		printf("\n");
		return CMD_RET_FAILURE;
	}

	printf("Watching %d GPIOs", count);
	if (bank_filter >= 0)
		printf(" in bank %d", bank_filter);
	printf(" for %u ms. Press/release the button now.\n", timeout_ms);

	start = get_timer(0);
	while (get_timer(start) < timeout_ms) {
		int i;

		if (ctrlc()) {
			puts("rkgpiowatch: stopped\n");
			return CMD_RET_SUCCESS;
		}

		for (i = 0; i < count; i++) {
			int value = rk3128_gpio_raw_value(watch[i].dev,
							  watch[i].offset);

			if (value < 0 || value == watch[i].last)
				continue;

			watch[i].last = value;

			{
				char name[16];

				rk3128_gpio_name(name, sizeof(name), &watch[i]);
				printf("%6lu ms  %-10s (gpio %u) -> %d\n",
				       get_timer(start), name, watch[i].gpio,
				       value);
			}
		}

		mdelay(RK3128_GPIO_WATCH_POLL_MS);
	}

	puts("rkgpiowatch: done\n");

	return CMD_RET_SUCCESS;
}

static int do_rkadcwatch(cmd_tbl_t *cmdtp, int flag, int argc,
			 char * const argv[])
{
	unsigned int timeout_ms = RK3128_ADC_WATCH_DEFAULT_MS;
	unsigned int threshold = 8;
	unsigned int data[RK3128_SARADC_CHANNELS];
	unsigned int last[RK3128_SARADC_CHANNELS];
	int valid[RK3128_SARADC_CHANNELS];
	int channel = -1;
	unsigned long start;
	int ch;
	int ret;

	if (argc > 4)
		return CMD_RET_USAGE;

	if (argc >= 2)
		timeout_ms = simple_strtoul(argv[1], NULL, 10);
	if (argc >= 3)
		channel = simple_strtoul(argv[2], NULL, 10);
	if (argc == 4)
		threshold = simple_strtoul(argv[3], NULL, 10);

	memset(valid, 0, sizeof(valid));

	for (ch = 0; ch < RK3128_SARADC_CHANNELS; ch++) {
		if (channel >= 0 && ch != channel)
			continue;

		ret = adc_channel_single_shot("saradc", ch, &data[ch]);
		if (ret)
			ret = adc_channel_single_shot("adc", ch, &data[ch]);
		if (ret)
			continue;

		last[ch] = data[ch];
		valid[ch] = 1;
		printf("adc%d = %u\n", ch, data[ch]);
	}

	for (ch = 0; ch < RK3128_SARADC_CHANNELS; ch++) {
		if (valid[ch])
			break;
	}

	if (ch == RK3128_SARADC_CHANNELS) {
		puts("rkadcwatch: no readable SARADC channels, check &saradc status\n");
		return CMD_RET_FAILURE;
	}

	printf("Watching SARADC");
	if (channel >= 0)
		printf(" channel %d", channel);
	else
		printf(" channels 0-%d", RK3128_SARADC_CHANNELS - 1);
	printf(" for %u ms. Press/release the button now.\n", timeout_ms);

	start = get_timer(0);
	while (get_timer(start) < timeout_ms) {
		if (ctrlc()) {
			puts("rkadcwatch: stopped\n");
			return CMD_RET_SUCCESS;
		}

		for (ch = 0; ch < RK3128_SARADC_CHANNELS; ch++) {
			unsigned int delta;

			if (!valid[ch])
				continue;

			ret = adc_channel_single_shot("saradc", ch, &data[ch]);
			if (ret)
				ret = adc_channel_single_shot("adc", ch, &data[ch]);
			if (ret)
				continue;

			if (data[ch] > last[ch])
				delta = data[ch] - last[ch];
			else
				delta = last[ch] - data[ch];

			if (delta < threshold)
				continue;

			printf("%6lu ms  adc%d -> %u (delta %u)\n",
			       get_timer(start), ch, data[ch], delta);
			last[ch] = data[ch];
		}

		mdelay(RK3128_ADC_WATCH_POLL_MS);
	}

	puts("rkadcwatch: done\n");

	return CMD_RET_SUCCESS;
}

U_BOOT_CMD(
	rkgpiowatch, 3, 0, do_rkgpiowatch,
	"========= CNN modded ========= Watch RK3128 GPIO transitions while you press a button",
	"[timeout_ms] [bank]\n"
	"    - print raw GPIO edges, even for pins not reserved by U-Boot\n"
	"      bank is optional and limits watching to gpio0..gpio3"
);

U_BOOT_CMD(
	rkadcwatch, 4, 0, do_rkadcwatch,
	"========= CNN modded ========= Watch RK3128 SARADC channels while you press a button",
	"[timeout_ms] [channel] [threshold]\n"
	"    - channel is optional; default watches channels 0-2\n"
	"      threshold is minimum ADC delta to print, default 8"
);
