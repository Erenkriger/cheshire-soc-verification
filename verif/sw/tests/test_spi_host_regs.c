// ============================================================================
// test_spi_host_regs.c — CPU-side equivalent of chs_spi_sba_vseq
//
// Configures SPI host and runs single/multi-byte TX command sequences.
// ============================================================================
#include "cheshire_util.h"

#define SPI_CTRL_SPIEN      (1u << 31)
#define SPI_CTRL_SW_RST     (1u << 30)
#define SPI_CTRL_OUTPUT_EN  (1u << 29)

#define SPI_CMD_DIR_TX      (2u)
#define SPI_CMD_SPEED_STD   (0u)

static inline uint32_t spi_cmd(uint16_t len_minus_1, int csaat, uint32_t speed, uint32_t dir) {
    return ((uint32_t)len_minus_1 & 0x1FFU) |
           ((uint32_t)(csaat & 1) << 9) |
           ((speed & 0x3U) << 10) |
           ((dir & 0x3U) << 12);
}

static int wait_spi_ready(int max_poll) {
    for (int i = 0; i < max_poll; i++) {
        if (REG32(SPI_BASE, SPI_STATUS) & SPI_STATUS_READY)
            return 0;
    }
    return -1;
}

static int wait_spi_idle(int max_poll) {
    for (int i = 0; i < max_poll; i++) {
        uint32_t st = REG32(SPI_BASE, SPI_STATUS);
        if ((st & SPI_STATUS_ACTIVE) == 0U)
            return 0;
    }
    return -1;
}

int main(void) {
    // Software reset pulse
    REG32(SPI_BASE, SPI_CONTROL) = SPI_CTRL_SW_RST;
    REG32(SPI_BASE, SPI_CONTROL) = 0x00000000U;

    // CPOL=0, CPHA=0, CLKDIV=24, CSNIDLE=4, CSNTRAIL=4, CSNLEAD=4
    REG32(SPI_BASE, SPI_CONFIGOPTS0) = 0x04440018U;
    REG32(SPI_BASE, SPI_CSID) = 0x00000000U;
    REG32(SPI_BASE, SPI_ERR_ENABLE) = 0x0000001FU;
    REG32(SPI_BASE, SPI_EVT_ENABLE) = 0x00000000U;

    REG32(SPI_BASE, SPI_CONTROL) = SPI_CTRL_SPIEN | SPI_CTRL_OUTPUT_EN;
    fence();

    if (wait_spi_ready(100000) != 0)
        return 1;

    // Single-byte TX: 0xA5
    REG32(SPI_BASE, SPI_TXDATA) = 0x000000A5U;
    REG32(SPI_BASE, SPI_COMMAND) = spi_cmd(0, 0, SPI_CMD_SPEED_STD, SPI_CMD_DIR_TX);
    if (wait_spi_idle(200000) != 0)
        return 2;

    // Multi-byte TX: 4 bytes (DE AD BE EF)
    REG32(SPI_BASE, SPI_TXDATA) = 0xEFBEADDEU;
    REG32(SPI_BASE, SPI_COMMAND) = spi_cmd(3, 0, SPI_CMD_SPEED_STD, SPI_CMD_DIR_TX);
    if (wait_spi_idle(300000) != 0)
        return 3;

    uint32_t err = REG32(SPI_BASE, SPI_ERR_STATUS);
    if (err != 0U) {
        REG32(SPI_BASE, SPI_ERR_STATUS) = err;  // W1C
        return 4;
    }

    return 0;
}
