// ============================================================================
// test_lvl_hard_periph_stress_matrix.c
// Hard-4: Matrix-style stress across GPIO/UART/SPI/I2C + SPM state tracking.
// ============================================================================
#include "cheshire_util.h"

#define SPM_STRESS_ADDR (SPM_BASE + 0x00028000UL)
#define UART_SCR        0x1C

int main(void) {
    volatile uint32_t *spm = (volatile uint32_t *)SPM_STRESS_ADDR;
    const uint32_t patterns[8] = {
        0x00000000U,
        0xFFFFFFFFU,
        0x55555555U,
        0xAAAAAAAAU,
        0x0000FFFFU,
        0xFFFF0000U,
        0x13579BDFU,
        0x2468ACE0U
    };

    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0xFFFFFFFFU;
    REG32(I2C_BASE, I2C_CTRL) = 0x00000001U;

    for (int outer = 0; outer < 8; outer++) {
        for (int inner = 0; inner < 64; inner++) {
            uint32_t p = patterns[outer] ^ (uint32_t)inner;
            uint32_t idx = (uint32_t)(outer * 64 + inner) & 63U;

            REG32(GPIO_BASE, GPIO_DIRECT_OUT) = p;
            REG32(SPI_BASE, SPI_CSID) = (uint32_t)(inner & 0x1);
            REG32(SPI_BASE, SPI_ERR_ENABLE) = (uint32_t)(inner & 0xF);
            REG32(UART_BASE, UART_SCR) = p & 0xFFU;
            (void)REG32(UART_BASE, UART_LSR);
            (void)REG32(I2C_BASE, I2C_STATUS);

            spm[idx] = p;
            fence();

            if ((REG32(SPI_BASE, SPI_CSID) & 0x1U) != (uint32_t)(inner & 0x1))
                return 10 + outer;
            if ((REG32(GPIO_BASE, GPIO_DIRECT_OUT) ^ p) != 0U)
                return 30 + inner;
            if (spm[idx] != p)
                return 90 + inner;
        }
    }

    return 0;
}
