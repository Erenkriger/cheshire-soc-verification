// ============================================================================
// test_error_inject.c — CPU-safe equivalent of chs_error_inject_vseq
//
// Notes:
// - JTAG DMI/SBA-specific fault injection (unmapped SBA accesses) cannot be
//   mirrored 1:1 from CPU mode without trap handling.
// - This test focuses on software-visible robustness checks.
// ============================================================================
#include "cheshire_util.h"

static int test_ro_write_behavior(void) {
    uint32_t lsr_before = REG32(UART_BASE, UART_LSR);
    REG32(UART_BASE, UART_LSR) = 0xFFU;
    fence();
    uint32_t lsr_after = REG32(UART_BASE, UART_LSR);

    if ((lsr_after & UART_LSR_THRE) == 0U)
        return 1;

    if ((lsr_before & UART_LSR_THRE) && !(lsr_after & UART_LSR_THRE))
        return 2;

    return 0;
}

static int test_spi_error_enable_path(void) {
    REG32(SPI_BASE, SPI_ERR_ENABLE) = 0x0000000FU;
    fence();

    if ((REG32(SPI_BASE, SPI_ERR_ENABLE) & 0x0FU) != 0x0FU)
        return 10;

    (void)REG32(SPI_BASE, SPI_STATUS);
    return 0;
}

static int test_i2c_nak_tolerance_path(void) {
    REG32(I2C_BASE, I2C_CTRL) = 0x00000001U;
    REG32(I2C_BASE, I2C_TIMING0) = 0x00640064U;

    // NAKOK=1, STOP=1, START=1, byte=0xFE
    REG32(I2C_BASE, I2C_FMTFIFO) = (1U << 12) | (1U << 9) | (1U << 8) | 0xFEU;
    fence();

    (void)REG32(I2C_BASE, I2C_STATUS);
    if ((REG32(I2C_BASE, I2C_CTRL) & 0x1U) == 0U)
        return 20;

    return 0;
}

static int test_recovery_like_storm(void) {
    // Rapid legal accesses as CPU-side resilience proxy.
    for (int i = 0; i < 64; i++) {
        REG32(GPIO_BASE, GPIO_DIRECT_OE) = (uint32_t)(i & 0xFFFF);
        REG32(GPIO_BASE, GPIO_DIRECT_OUT) = (uint32_t)(1U << (i & 0xF));
        (void)REG32(UART_BASE, UART_LSR);
        (void)REG32(SPI_BASE, SPI_STATUS);
        (void)REG32(I2C_BASE, I2C_STATUS);
    }

    if ((REG32(GPIO_BASE, GPIO_DIRECT_OE) & 0xFFFFU) != (63U & 0xFFFFU))
        return 30;

    return 0;
}

int main(void) {
    int ret;

    ret = test_ro_write_behavior();
    if (ret) return ret;

    ret = test_spi_error_enable_path();
    if (ret) return ret;

    ret = test_i2c_nak_tolerance_path();
    if (ret) return ret;

    ret = test_recovery_like_storm();
    if (ret) return ret;

    return 0;
}
