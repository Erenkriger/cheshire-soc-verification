// ============================================================================
// test_i2c_host_regs.c — CPU-side equivalent of chs_i2c_sba_vseq
//
// Configures I2C host timing and dispatches single + multi-byte transactions.
// ============================================================================
#include "cheshire_util.h"

static inline uint32_t i2c_fdata(uint8_t byte, int start, int stop, int read, int rcont, int nakok) {
    return ((uint32_t)(nakok & 1) << 12) |
           ((uint32_t)(rcont & 1) << 11) |
           ((uint32_t)(read  & 1) << 10) |
           ((uint32_t)(stop  & 1) << 9)  |
           ((uint32_t)(start & 1) << 8)  |
           (uint32_t)byte;
}

static int wait_host_idle(int max_poll) {
    for (int i = 0; i < max_poll; i++) {
        uint32_t st = REG32(I2C_BASE, I2C_STATUS);
        if ((st & I2C_STATUS_HOSTIDLE) && (st & I2C_STATUS_FMTEMPTY))
            return 0;
    }
    return -1;
}

int main(void) {
    // FIFO reset pulse
    REG32(I2C_BASE, I2C_FIFO_CTRL) = 0x00000103U;
    REG32(I2C_BASE, I2C_FIFO_CTRL) = 0x00000000U;

    // ~100kHz target for 50MHz system clock
    REG32(I2C_BASE, I2C_TIMING0) = ((uint32_t)250U << 16) | 250U;
    REG32(I2C_BASE, I2C_TIMING1) = ((uint32_t)10U << 16) | 10U;
    REG32(I2C_BASE, I2C_TIMING2) = ((uint32_t)25U << 16) | 25U;
    REG32(I2C_BASE, I2C_TIMING3) = ((uint32_t)5U  << 16) | 5U;
    REG32(I2C_BASE, I2C_TIMING4) = ((uint32_t)25U << 16) | 25U;

    REG32(I2C_BASE, I2C_INTR_STATE) = 0x00007FFFU;
    REG32(I2C_BASE, I2C_INTR_EN) = 0x00000000U;

    // Enable host mode
    REG32(I2C_BASE, I2C_CTRL) = 0x00000001U;
    fence();

    if ((REG32(I2C_BASE, I2C_CTRL) & 0x1U) == 0U)
        return 1;

    // Single write: START + 0x50(W), DATA 0xA5 + STOP (NAKOK set)
    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0xA0U, 1, 0, 0, 0, 1);
    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0xA5U, 0, 1, 0, 0, 1);
    if (wait_host_idle(200000) != 0)
        return 2;

    // Multi-byte write: START + 0x68(W), 0x01,0x02,0x03 + STOP
    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0xD0U, 1, 0, 0, 0, 1);
    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0x01U, 0, 0, 0, 0, 1);
    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0x02U, 0, 0, 0, 0, 1);
    REG32(I2C_BASE, I2C_FMTFIFO) = i2c_fdata(0x03U, 0, 1, 0, 0, 1);
    if (wait_host_idle(300000) != 0)
        return 3;

    // Clear pending status/interrupt bits
    uint32_t intr = REG32(I2C_BASE, I2C_INTR_STATE);
    REG32(I2C_BASE, I2C_INTR_STATE) = intr;

    return 0;
}
