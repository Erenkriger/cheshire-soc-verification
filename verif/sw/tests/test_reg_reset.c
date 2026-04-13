// ============================================================================
// test_reg_reset.c — CPU-side equivalent of chs_reg_reset_vseq
//
// Checks key post-reset register values with conservative masks.
// ============================================================================
#include "cheshire_util.h"

static int expect_mask(uint32_t got, uint32_t exp, uint32_t mask, int err) {
    if ((got & mask) != (exp & mask))
        return err;
    return 0;
}

int main(void) {
    int ret;

    // GPIO reset values
    ret = expect_mask(REG32(GPIO_BASE, GPIO_INTR_STATE), 0x00000000U, 0xFFFFFFFFU, 1);
    if (ret) return ret;
    ret = expect_mask(REG32(GPIO_BASE, GPIO_INTR_EN), 0x00000000U, 0xFFFFFFFFU, 2);
    if (ret) return ret;
    ret = expect_mask(REG32(GPIO_BASE, GPIO_DIRECT_OUT), 0x00000000U, 0xFFFFFFFFU, 3);
    if (ret) return ret;
    ret = expect_mask(REG32(GPIO_BASE, GPIO_DIRECT_OE), 0x00000000U, 0xFFFFFFFFU, 4);
    if (ret) return ret;

    // UART reset values
    ret = expect_mask(REG32(UART_BASE, UART_IER), 0x00000000U, 0x0000000FU, 10);
    if (ret) return ret;
    ret = expect_mask(REG32(UART_BASE, UART_LCR), 0x00000000U, 0x000000FFU, 11);
    if (ret) return ret;
    ret = expect_mask(REG32(UART_BASE, UART_MCR), 0x00000000U, 0x0000001FU, 12);
    if (ret) return ret;
    if ((REG32(UART_BASE, UART_LSR) & UART_LSR_THRE) == 0U)
        return 13;

    // SPI reset checks
    if (REG32(SPI_BASE, SPI_CONTROL) & (1u << 31))
        return 20;
    ret = expect_mask(REG32(SPI_BASE, SPI_CSID), 0x00000000U, 0xFFFFFFFFU, 21);
    if (ret) return ret;

    // I2C reset checks
    ret = expect_mask(REG32(I2C_BASE, I2C_INTR_STATE), 0x00000000U, 0x00007FFFU, 30);
    if (ret) return ret;
    ret = expect_mask(REG32(I2C_BASE, I2C_CTRL), 0x00000000U, 0x00000001U, 31);
    if (ret) return ret;

    // Host idle and fmtempty should be high in default idle state.
    uint32_t i2c_status = REG32(I2C_BASE, I2C_STATUS);
    if ((i2c_status & I2C_STATUS_HOSTIDLE) == 0U)
        return 32;
    if ((i2c_status & I2C_STATUS_FMTEMPTY) == 0U)
        return 33;

    return 0;
}
