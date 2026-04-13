// ============================================================================
// test_memmap_sweep.c — CPU-side equivalent of chs_memmap_vseq
//
// Validates key memory regions and peripheral register accessibility from CPU.
// ============================================================================
#include "cheshire_util.h"

#define CLINT_MSIP_OFF      0x0000
#define CLINT_MTIME_LO_OFF  0xBFF8
#define PLIC_PRIO0_OFF      0x0000

#define SPM_TEST_ADDR       (SPM_BASE + 0x00009000UL)
#define DRAM_TEST_ADDR      (DRAM_BASE + 0x00110000UL)

static int test_soc_regs_rw(void) {
    uint32_t p0 = 0x1234ABCDU;
    uint32_t p1 = 0xA5A55A5AU;

    REG32(REGS_BASE, CHS_SCRATCH0_OFF) = p0;
    REG32(REGS_BASE, CHS_SCRATCH1_OFF) = p1;
    fence();

    if (REG32(REGS_BASE, CHS_SCRATCH0_OFF) != p0)
        return 1;
    if (REG32(REGS_BASE, CHS_SCRATCH1_OFF) != p1)
        return 2;

    return 0;
}

static int test_region_probe(void) {
    uint32_t boot_nonzero = 0;

    // Core peripheral probes
    (void)REG32(UART_BASE, UART_LSR);
    (void)REG32(SPI_BASE, SPI_STATUS);
    (void)REG32(I2C_BASE, I2C_STATUS);
    (void)REG32(GPIO_BASE, GPIO_DATA_IN);
    (void)REG32(SLINK_BASE, 0x00);

    // Platform regions
    (void)REG32(CLINT_BASE, CLINT_MSIP_OFF);
    (void)REG32(CLINT_BASE, CLINT_MTIME_LO_OFF);
    (void)REG32(PLIC_BASE, PLIC_PRIO0_OFF);

    // Boot ROM probe (expect at least one non-zero instruction word)
    for (int i = 0; i < 8; i++) {
        uint32_t w = REG32(BOOTROM_BASE, (uint32_t)(i * 4));
        if (w != 0U)
            boot_nonzero++;
    }

    if (boot_nonzero == 0U)
        return 10;

    if ((REG32(UART_BASE, UART_LSR) & UART_LSR_THRE) == 0U)
        return 11;

    return 0;
}

static int test_spm_dram_rw(void) {
    volatile uint32_t *spm = (volatile uint32_t *)SPM_TEST_ADDR;
    volatile uint32_t *dram = (volatile uint32_t *)DRAM_TEST_ADDR;

    spm[0] = 0xCAFE1001U;
    spm[1] = 0xCAFE1002U;
    dram[0] = 0xD00D2001U;
    dram[1] = 0xD00D2002U;
    fence();

    if (spm[0] != 0xCAFE1001U || spm[1] != 0xCAFE1002U)
        return 20;
    if (dram[0] != 0xD00D2001U || dram[1] != 0xD00D2002U)
        return 21;

    return 0;
}

int main(void) {
    int ret;

    ret = test_soc_regs_rw();
    if (ret) return ret;

    ret = test_region_probe();
    if (ret) return ret;

    ret = test_spm_dram_rw();
    if (ret) return ret;

    return 0;
}
