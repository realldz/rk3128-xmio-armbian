#ifndef __ASM_ARCH_RK3128_STORAGE_H
#define __ASM_ARCH_RK3128_STORAGE_H

#include <common.h>

bool rk3128_nand_is_present(void);
void rk3128_configure_emmc_pins(void);
void rk3128_configure_nand_pins(void);

#endif
