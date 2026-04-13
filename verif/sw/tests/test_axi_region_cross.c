// ============================================================================
// test_axi_region_cross.c — CPU-side equivalent of chs_cov_axi_region_vseq
//
// Probes multiple mapped regions and performs SPM/DRAM read-write sweeps.
// ============================================================================
#include "cheshire_util.h"

#define CLINT_MSIP_OFF      0x0000
#define CLINT_MTIME_LO_OFF  0xBFF8
#define PLIC_PRIO1_OFF      0x0004

#define SPM_AXI_BASE        (SPM_BASE + 0x0000A000UL)
#define DRAM_AXI_BASE       (DRAM_BASE + 0x00120000UL)

static int probe_regions(void) {
    (void)REG32(BOOTROM_BASE, 0x00);
    (void)REG32(CLINT_BASE, CLINT_MSIP_OFF);
    (void)REG32(CLINT_BASE, CLINT_MTIME_LO_OFF);
    (void)REG32(PLIC_BASE, PLIC_PRIO1_OFF);

    (void)REG32(REGS_BASE, CHS_PLATFORM_OFF);
    (void)REG32(REGS_BASE, CHS_NUM_INT_OFF);

    (void)REG32(UART_BASE, UART_LSR);
    (void)REG32(SPI_BASE, SPI_STATUS);
    (void)REG32(I2C_BASE, I2C_STATUS);
    (void)REG32(GPIO_BASE, GPIO_DATA_IN);

    return 0;
}

static int test_spm_window(void) {
    volatile uint32_t *spm = (volatile uint32_t *)SPM_AXI_BASE;

    for (int i = 0; i < 16; i++)
        spm[i] = 0xABCD0000U + (uint32_t)i;
    fence();

    for (int i = 0; i < 16; i++) {
        uint32_t exp = 0xABCD0000U + (uint32_t)i;
        if (spm[i] != exp)
            return 10 + i;
    }

    return 0;
}

static int test_dram_window(void) {
    volatile uint32_t *dram = (volatile uint32_t *)DRAM_AXI_BASE;

    for (int i = 0; i < 32; i++)
        dram[i] = 0xD0000000U + (uint32_t)i;
    fence();

    for (int i = 0; i < 32; i++) {
        uint32_t exp = 0xD0000000U + (uint32_t)i;
        if (dram[i] != exp)
            return 50 + i;
    }

    return 0;
}

int main(void) {
    int ret;

    ret = probe_regions();
    if (ret) return ret;

    ret = test_spm_window();
    if (ret) return ret;

    ret = test_dram_window();
    if (ret) return ret;

    return 0;
}
