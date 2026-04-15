// ============================================================================
// test_lvl_medium_interleave_rw.c
// Medium-5: Interleaved GPIO/UART/SPI/I2C + DRAM access with consistency check.
// ============================================================================
#include "cheshire_util.h"

#define DRAM_MED_BASE (DRAM_BASE + 0x00020000UL)

int main(void) {
    volatile uint32_t *dram = (volatile uint32_t *)DRAM_MED_BASE;
    uint32_t expected[32];

    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0x0000FFFFU;
    REG32(SPI_BASE, SPI_CSID) = 0x00000000U;
    REG32(I2C_BASE, I2C_CTRL) = 0x00000001U;
    fence();

    for (int i = 0; i < 32; i++) {
        expected[i] = 0U;
        dram[i] = 0U;
    }

    for (uint32_t round = 0; round < 256U; round++) {
        uint32_t idx = round & 31U;
        uint32_t pattern = (round * 0x01010101U) ^ 0xA5A55A5AU;

        REG32(GPIO_BASE, GPIO_DIRECT_OUT) = pattern;
        REG32(REGS_BASE, CHS_SCRATCH0_OFF) = pattern;
        REG32(SPI_BASE, SPI_CSID) = round & 0x1U;
        (void)REG32(UART_BASE, UART_LSR);
        (void)REG32(SPI_BASE, SPI_STATUS);
        (void)REG32(I2C_BASE, I2C_STATUS);

        dram[idx] = pattern;
        expected[idx] = pattern;
    }

    fence();

    for (int i = 0; i < 32; i++) {
        if (dram[i] != expected[i])
            return 10 + i;
    }

    return 0;
}
