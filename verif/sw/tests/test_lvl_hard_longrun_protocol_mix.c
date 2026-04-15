// ============================================================================
// test_lvl_hard_longrun_protocol_mix.c
// Hard-3: Long-run mixed protocol traffic and DRAM ring-buffer consistency.
// ============================================================================
#include "cheshire_util.h"

#define DRAM_RING_ADDR  (DRAM_BASE + 0x00050000UL)

int main(void) {
    volatile uint32_t *ring = (volatile uint32_t *)DRAM_RING_ADDR;
    uint32_t expected[128];
    uint32_t checksum = 0U;

    uint32_t rtc_freq = REG32(REGS_BASE, CHS_RTC_FREQ_OFF);
    uint32_t core_freq = (rtc_freq > 0U) ? (rtc_freq * 1526U) : 50000000U;

    uart_init(core_freq, 115200U);
    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0x0000FFFFU;
    REG32(I2C_BASE, I2C_CTRL) = 0x00000001U;

    for (int i = 0; i < 128; i++) {
        ring[i] = 0U;
        expected[i] = 0U;
    }

    for (uint32_t i = 0; i < 2048U; i++) {
        uint32_t idx = i & 127U;
        uint32_t pattern = (i * 0x00102031U) ^ 0xA55A33CCU;

        REG32(GPIO_BASE, GPIO_DIRECT_OUT) = pattern;
        REG32(SPI_BASE, SPI_CSID) = i & 0x1U;
        (void)REG32(SPI_BASE, SPI_STATUS);
        (void)REG32(I2C_BASE, I2C_STATUS);

        ring[idx] = pattern;
        expected[idx] = pattern;
        checksum ^= pattern;

        if ((i & 63U) == 0U)
            uart_putc('.');
    }

    fence();

    for (int i = 0; i < 128; i++) {
        if (ring[i] != expected[i])
            return 10 + i;
    }

    REG32(REGS_BASE, CHS_SCRATCH0_OFF) = checksum;
    if (REG32(REGS_BASE, CHS_SCRATCH0_OFF) != checksum)
        return 200;

    return 0;
}
