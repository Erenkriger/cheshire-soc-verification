// ============================================================================
// test_allproto.c — CPU-side equivalent of chs_cov_allproto_vseq
//
// Drives GPIO/UART/SPI/I2C in one program to emulate all-protocol activation
// and cross-protocol interleaving from software.
// ============================================================================
#include "cheshire_util.h"

#define SPI_CMD_TX_1B_CSAAT   0x003A6004U
#define SPI_CMD_TX_4B_CSAAT   0x00FA6004U
#define SPI_CMD_TX_1B_CSREL   0x003A4004U

static inline uint32_t i2c_fdata(uint8_t byte, int start, int stop, int read, int rcont, int nakok) {
    return ((uint32_t)(nakok & 1) << 12) |
           ((uint32_t)(rcont & 1) << 11) |
           ((uint32_t)(read  & 1) << 10) |
           ((uint32_t)(stop  & 1) << 9)  |
           ((uint32_t)(start & 1) << 8)  |
           byte;
}

static int activate_gpio_uart(void) {
    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0xFFFFFFFFU;
    REG32(GPIO_BASE, GPIO_DIRECT_OUT) = 0x55555555U;
    REG32(GPIO_BASE, GPIO_DIRECT_OUT) = 0xAAAAAAAAU;

    uint32_t rtc_freq = REG32(REGS_BASE, CHS_RTC_FREQ_OFF);
    uint32_t core_freq = (rtc_freq > 0U) ? (rtc_freq * 1526U) : 50000000U;
    uart_init(core_freq, 115200U);
    uart_putc('H');
    uart_putc('i');
    return 0;
}

static int activate_spi(void) {
    REG32(SPI_BASE, SPI_CONTROL) = 0x80000001U;
    REG32(SPI_BASE, SPI_CONFIGOPTS0) = 0x00180000U;
    REG32(SPI_BASE, SPI_CSID) = 0x00000000U;

    REG32(SPI_BASE, SPI_TXDATA) = 0x0000009FU;
    REG32(SPI_BASE, SPI_COMMAND) = SPI_CMD_TX_1B_CSAAT;

    REG32(SPI_BASE, SPI_TXDATA) = 0xDEADBEEFU;
    REG32(SPI_BASE, SPI_COMMAND) = SPI_CMD_TX_4B_CSAAT;
    REG32(SPI_BASE, SPI_COMMAND) = SPI_CMD_TX_1B_CSREL;

    return 0;
}

static int activate_i2c(void) {
    REG32(I2C_BASE, I2C_CTRL) = 0x00000001U;
    REG32(I2C_BASE, I2C_TIMING0) = ((uint32_t)250U << 16) | 250U;
    REG32(I2C_BASE, I2C_TIMING0 + 0x04U) = ((uint32_t)250U << 16) | 250U;
    REG32(I2C_BASE, I2C_TIMING0 + 0x08U) = ((uint32_t)250U << 16) | 250U;
    REG32(I2C_BASE, I2C_TIMING0 + 0x0CU) = 5U;

    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0xA0U, 1, 0, 0, 0, 0);
    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0xABU, 0, 0, 0, 1, 0);
    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0x00U, 0, 1, 0, 0, 0);

    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0xA1U, 1, 0, 0, 0, 0);
    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0x01U, 0, 1, 1, 0, 1);

    if ((REG32(I2C_BASE, I2C_CTRL) & 0x1U) == 0U)
        return 30;
    return 0;
}

static int cross_protocol_interleave(void) {
    for (int i = 0; i < 3; i++) {
        REG32(GPIO_BASE, GPIO_DIRECT_OUT) = (1U << i);
        uart_putc((char)('0' + i));
        REG32(SPI_BASE, SPI_TXDATA) = (uint32_t)(0xA0 + i);
        REG32(SPI_BASE, SPI_COMMAND) = SPI_CMD_TX_1B_CSAAT;
        REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0xA0U, 1, 0, 0, 1, 0);
    }

    REG32(GPIO_BASE, GPIO_DIRECT_OUT) = 0x00000000U;
    if (REG32(GPIO_BASE, GPIO_DIRECT_OUT) != 0x00000000U)
        return 40;
    return 0;
}

int main(void) {
    int ret;

    ret = activate_gpio_uart();
    if (ret) return ret;

    ret = activate_spi();
    if (ret) return ret;

    ret = activate_i2c();
    if (ret) return ret;

    ret = cross_protocol_interleave();
    if (ret) return ret;

    return 0;
}
