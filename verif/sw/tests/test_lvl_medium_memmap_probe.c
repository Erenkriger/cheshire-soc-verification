// ============================================================================
// test_lvl_medium_memmap_probe.c
// Medium-1: Probe main SoC regions and validate key register accessibility.
// ============================================================================
#include "cheshire_util.h"

#define CLINT_MSIP_OFF      0x0000
#define CLINT_MTIME_LO_OFF  0xBFF8
#define PLIC_PRIO0_OFF      0x0000

int main(void) {
    uint32_t boot_nonzero = 0U;

    REG32(REGS_BASE, CHS_SCRATCH0_OFF) = 0x10010000U;
    REG32(REGS_BASE, CHS_SCRATCH1_OFF) = 0x5A5AA5A5U;
    fence();

    if (REG32(REGS_BASE, CHS_SCRATCH1_OFF) != 0x5A5AA5A5U)
        return 1;

    (void)REG32(UART_BASE, UART_LSR);
    (void)REG32(SPI_BASE, SPI_STATUS);
    (void)REG32(I2C_BASE, I2C_STATUS);
    (void)REG32(GPIO_BASE, GPIO_DATA_IN);
    (void)REG32(SLINK_BASE, 0x00);
    (void)REG32(CLINT_BASE, CLINT_MSIP_OFF);
    (void)REG32(CLINT_BASE, CLINT_MTIME_LO_OFF);
    (void)REG32(PLIC_BASE, PLIC_PRIO0_OFF);

    for (int i = 0; i < 8; i++) {
        uint32_t w = REG32(BOOTROM_BASE, (uint32_t)(i * 4));
        if (w != 0U)
            boot_nonzero++;
    }

    if (boot_nonzero == 0U)
        return 2;
    if ((REG32(UART_BASE, UART_LSR) & UART_LSR_THRE) == 0U)
        return 3;

    return 0;
}
