// ============================================================================
// test_lvl_hard_recovery_resilience.c
// Hard-5: Aggressive legal reconfiguration loops and end-state health checks.
// ============================================================================
#include "cheshire_util.h"

static int uart_reconfig_loop(void) {
    for (uint32_t i = 1U; i <= 32U; i++) {
        REG32(UART_BASE, UART_LCR) = UART_LCR_DLAB;
        REG32(UART_BASE, UART_DLL) = i & 0xFFU;
        REG32(UART_BASE, UART_DLH) = (i >> 8) & 0xFFU;
        REG32(UART_BASE, UART_LCR) = 0x03U;

        if ((REG32(UART_BASE, UART_LSR) & UART_LSR_THRE) == 0U)
            return 1;
    }
    return 0;
}

static int spi_i2c_recovery_loop(void) {
    for (uint32_t i = 0U; i < 64U; i++) {
        REG32(SPI_BASE, SPI_ERR_ENABLE) = i & 0xFU;
        REG32(SPI_BASE, SPI_CSID) = i & 0x1U;
        (void)REG32(SPI_BASE, SPI_STATUS);

        REG32(I2C_BASE, I2C_CTRL) = 0x00000001U;
        REG32(I2C_BASE, I2C_TIMING0) = 0x00640064U + i;
        REG32(I2C_BASE, I2C_FMTFIFO) = (1U << 12) | (1U << 9) | (1U << 8) | (i & 0xFFU);
    }

    if ((REG32(I2C_BASE, I2C_CTRL) & 0x1U) == 0U)
        return 2;

    return 0;
}

static int final_health_check(void) {
    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0x0000FFFFU;
    REG32(GPIO_BASE, GPIO_DIRECT_OUT) = 0x00005AA5U;
    REG32(REGS_BASE, CHS_SCRATCH0_OFF) = 0xA5A55A5AU;
    fence();

    if ((REG32(GPIO_BASE, GPIO_DIRECT_OE) & 0x0000FFFFU) != 0x0000FFFFU)
        return 10;
    if ((REG32(GPIO_BASE, GPIO_DIRECT_OUT) & 0x0000FFFFU) != 0x00005AA5U)
        return 11;
    if (REG32(REGS_BASE, CHS_SCRATCH0_OFF) != 0xA5A55A5AU)
        return 12;

    return 0;
}

int main(void) {
    int ret;

    ret = uart_reconfig_loop();
    if (ret)
        return ret;

    ret = spi_i2c_recovery_loop();
    if (ret)
        return ret;

    ret = final_health_check();
    if (ret)
        return ret;

    return 0;
}
