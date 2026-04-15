// ============================================================================
// test_lvl_medium_spi_i2c_cfg.c
// Medium-4: SPI Host and I2C Host configuration + basic command path exercise.
// ============================================================================
#include "cheshire_util.h"

#define SPI_CMD_TX1 0x003A4004U

static inline uint32_t i2c_fdata(uint8_t byte, int start, int stop, int read, int rcont, int nakok) {
    return ((uint32_t)(nakok & 1) << 12) |
           ((uint32_t)(rcont & 1) << 11) |
           ((uint32_t)(read  & 1) << 10) |
           ((uint32_t)(stop  & 1) << 9)  |
           ((uint32_t)(start & 1) << 8)  |
           byte;
}

int main(void) {
    // SPI setup
    REG32(SPI_BASE, SPI_CONTROL) = 0x80000001U;
    REG32(SPI_BASE, SPI_CONFIGOPTS0) = 0x00180000U;
    REG32(SPI_BASE, SPI_CSID) = 0x00000001U;
    REG32(SPI_BASE, SPI_ERR_ENABLE) = 0x0000000FU;
    fence();

    if ((REG32(SPI_BASE, SPI_CSID) & 0x1U) != 0x1U)
        return 1;
    if ((REG32(SPI_BASE, SPI_ERR_ENABLE) & 0x0FU) != 0x0FU)
        return 2;

    REG32(SPI_BASE, SPI_TXDATA) = 0x0000009FU;
    REG32(SPI_BASE, SPI_COMMAND) = SPI_CMD_TX1;

    // I2C setup
    REG32(I2C_BASE, I2C_CTRL) = 0x00000001U;
    REG32(I2C_BASE, I2C_TIMING0) = 0x00640064U;
    REG32(I2C_BASE, I2C_TIMING1) = 0x00640064U;
    REG32(I2C_BASE, I2C_FIFO_CTRL) = 0x00000003U;
    fence();

    if ((REG32(I2C_BASE, I2C_CTRL) & 0x1U) == 0U)
        return 3;

    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0xA0U, 1, 0, 0, 1, 0);
    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0x11U, 0, 0, 0, 1, 0);
    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0x22U, 0, 1, 0, 0, 0);

    return 0;
}
