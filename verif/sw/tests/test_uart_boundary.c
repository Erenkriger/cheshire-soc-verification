// ============================================================================
// test_uart_boundary.c — CPU-side equivalent of chs_cov_uart_boundary_vseq
//
// Sends boundary values plus pseudo-random stream and checks UART readiness.
// ============================================================================
#include "cheshire_util.h"

static int wait_thre(int max_poll) {
    for (int i = 0; i < max_poll; i++) {
        if (REG32(UART_BASE, UART_LSR) & UART_LSR_THRE)
            return 0;
    }
    return -1;
}

static uint8_t xorshift8(uint8_t v) {
    v ^= (uint8_t)(v << 3);
    v ^= (uint8_t)(v >> 5);
    v ^= (uint8_t)(v << 1);
    return v;
}

int main(void) {
    uint32_t rtc_freq = REG32(REGS_BASE, CHS_RTC_FREQ_OFF);
    uint32_t core_freq = (rtc_freq > 0U) ? (rtc_freq * 1526U) : 50000000U;

    uart_init(core_freq, 115200U);

    if (wait_thre(50000) != 0)
        return 1;

    REG32(UART_BASE, UART_LCR) = 0x03U;  // 8N1
    fence();
    if ((REG32(UART_BASE, UART_LCR) & 0xFFU) != 0x03U)
        return 2;

    const uint8_t boundary[] = {0x00U, 0x01U, 0x7FU, 0x80U, 0xFEU, 0xFFU};
    for (unsigned i = 0; i < sizeof(boundary); i++)
        uart_putc((char)boundary[i]);

    uart_puts("UART_BOUNDARY_START\r\n");

    uint8_t v = 0x5AU;
    for (int i = 0; i < 128; i++) {
        v = xorshift8(v);
        uart_putc((char)v);
    }

    uart_puts("\r\nUART_BOUNDARY_DONE\r\n");

    if (wait_thre(50000) != 0)
        return 3;

    return 0;
}
