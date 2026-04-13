// ============================================================================
// test_periph_stress.c — CPU-side equivalent of chs_periph_stress_vseq
//
// Stresses GPIO/UART/SPI/I2C plus DRAM with rapid mixed access patterns.
// ============================================================================
#include "cheshire_util.h"

static int phase_wr_rd_alternation(void) {
    for (int round = 0; round < 10; round++) {
        uint32_t pattern = 1U << (round % 16);
        uint32_t rdata;

        REG32(GPIO_BASE, GPIO_DIRECT_OE) = pattern;
        rdata = REG32(GPIO_BASE, GPIO_DIRECT_OE);
        if (rdata != pattern)
            return 10 + round;

        REG32(UART_BASE, 0x1C) = (pattern & 0xFFU);
        rdata = REG32(UART_BASE, 0x1C) & 0xFFU;
        if (rdata != (pattern & 0xFFU))
            return 30 + round;

        REG32(SPI_BASE, SPI_CSID) = (uint32_t)(round & 0x1);
        rdata = REG32(I2C_BASE, I2C_STATUS);
        (void)rdata;
    }
    return 0;
}

static int phase_back_to_back(void) {
    for (int i = 0; i < 8; i++)
        REG32(GPIO_BASE, GPIO_DIRECT_OUT) = (1U << i);

    if (REG32(GPIO_BASE, GPIO_DIRECT_OUT) != 0x00000080U)
        return 50;
    return 0;
}

static int phase_walking_address(void) {
    const uintptr_t addrs[5] = {
        GPIO_BASE + GPIO_DIRECT_OE,
        UART_BASE + 0x1C,
        SPI_BASE + SPI_CSID,
        GPIO_BASE + GPIO_DIRECT_OUT,
        I2C_BASE + I2C_CTRL
    };

    for (int i = 0; i < 5; i++)
        (*(volatile uint32_t *)addrs[i]) = (uint32_t)(i + 1);

    if ((*(volatile uint32_t *)addrs[4] & 0x1U) == 0U)
        return 60;
    return 0;
}

static int phase_data_patterns(void) {
    const uint32_t patterns[6] = {
        0x00000000U,
        0xFFFFFFFFU,
        0x55555555U,
        0xAAAAAAAAU,
        0xDEADBEEFU,
        0x12345678U
    };

    for (int i = 0; i < 6; i++) {
        REG32(GPIO_BASE, GPIO_DIRECT_OE) = patterns[i];
        if (REG32(GPIO_BASE, GPIO_DIRECT_OE) != patterns[i])
            return 70 + i;
    }
    return 0;
}

static int phase_dram_burst(void) {
    volatile uint32_t *dram = (volatile uint32_t *)DRAM_BASE;

    for (int i = 0; i < 8; i++)
        dram[i] = 0xCAFE0000U + (uint32_t)i;
    fence();

    for (int i = 0; i < 8; i++) {
        uint32_t expected = 0xCAFE0000U + (uint32_t)i;
        if (dram[i] != expected)
            return 90 + i;
    }
    return 0;
}

static int phase_final_health(void) {
    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0x0000DEADU;
    if (REG32(GPIO_BASE, GPIO_DIRECT_OE) != 0x0000DEADU)
        return 110;

    REG32(UART_BASE, 0x1C) = 0x42U;
    if ((REG32(UART_BASE, 0x1C) & 0xFFU) != 0x42U)
        return 111;

    REG32(SPI_BASE, SPI_CSID) = 0x0U;
    if ((REG32(SPI_BASE, SPI_CSID) & 0x1U) != 0x0U)
        return 112;

    (void)REG32(I2C_BASE, I2C_STATUS);
    return 0;
}

int main(void) {
    int ret;

    ret = phase_wr_rd_alternation();
    if (ret) return ret;

    ret = phase_back_to_back();
    if (ret) return ret;

    ret = phase_walking_address();
    if (ret) return ret;

    ret = phase_data_patterns();
    if (ret) return ret;

    ret = phase_dram_burst();
    if (ret) return ret;

    ret = phase_final_health();
    if (ret) return ret;

    return 0;
}
