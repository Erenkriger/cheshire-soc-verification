// ============================================================================
// test_concurrent.c — CPU-side equivalent of chs_concurrent_vseq
//
// Exercises GPIO/UART/SPI/I2C in round-robin order to stress interconnect and
// basic peripheral register accessibility from software.
// ============================================================================
#include "cheshire_util.h"

static int init_peripherals(void) {
    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0x0000FFFF;
    REG32(UART_BASE, UART_LCR) = 0x03;
    REG32(SPI_BASE, SPI_CONFIGOPTS0) = 0x04040418;
    REG32(I2C_BASE, I2C_CTRL) = 0x00000001;
    fence();

    if ((REG32(I2C_BASE, I2C_CTRL) & 0x1U) == 0)
        return 1;
    return 0;
}

static int round_robin_access(void) {
    for (int round = 0; round < 5; round++) {
        uint32_t pattern = 1U << round;
        uint32_t rdata;

        REG32(GPIO_BASE, GPIO_DIRECT_OUT) = pattern;

        rdata = REG32(UART_BASE, UART_LSR);
        (void)rdata;
        rdata = REG32(SPI_BASE, SPI_STATUS);
        (void)rdata;
        rdata = REG32(I2C_BASE, I2C_STATUS);
        (void)rdata;

        rdata = REG32(GPIO_BASE, GPIO_DIRECT_OUT);
        if ((rdata & 0x0000FFFFU) != (pattern & 0x0000FFFFU))
            return 10 + round;
    }
    return 0;
}

static int reverse_readback_sweep(void) {
    uint32_t rdata;

    REG32(GPIO_BASE, GPIO_DIRECT_OUT) = 0x0000CAFE;
    REG32(SPI_BASE, SPI_CSID) = 0x00000001;
    REG32(UART_BASE, UART_MCR) = 0x00000000;
    REG32(I2C_BASE, I2C_CTRL) = 0x00000001;
    fence();

    rdata = REG32(I2C_BASE, I2C_CTRL);
    if ((rdata & 0x1U) == 0)
        return 20;

    rdata = REG32(UART_BASE, UART_MCR);
    if ((rdata & 0xFFU) != 0x00)
        return 21;

    rdata = REG32(SPI_BASE, SPI_CSID);
    if ((rdata & 0x1U) != 0x1U)
        return 22;

    rdata = REG32(GPIO_BASE, GPIO_DIRECT_OUT);
    if ((rdata & 0x0000FFFFU) != 0x0000CAFEU)
        return 23;

    return 0;
}

int main(void) {
    int ret;

    ret = init_peripherals();
    if (ret) return ret;

    ret = round_robin_access();
    if (ret) return ret;

    ret = reverse_readback_sweep();
    if (ret) return ret;

    return 0;
}
