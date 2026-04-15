// ============================================================================
// test_lvl_easy_uart_hello.c
// Easy-1: Boot + UART smoke + Cheshire scratch register sanity.
// ============================================================================
#include "cheshire_util.h"

int main(void) {
    uint32_t rtc_freq = REG32(REGS_BASE, CHS_RTC_FREQ_OFF);
    uint32_t core_freq = (rtc_freq > 0U) ? (rtc_freq * 1526U) : 50000000U;

    uart_init(core_freq, 115200U);
    uart_puts("[EASY] UART hello start\r\n");

    REG32(REGS_BASE, CHS_SCRATCH0_OFF) = 0xE0010001U;
    REG32(REGS_BASE, CHS_SCRATCH1_OFF) = 0xE0010002U;
    fence();

    if (REG32(REGS_BASE, CHS_SCRATCH0_OFF) != 0xE0010001U)
        return 1;
    if (REG32(REGS_BASE, CHS_SCRATCH1_OFF) != 0xE0010002U)
        return 2;
    if ((REG32(UART_BASE, UART_LSR) & UART_LSR_THRE) == 0U)
        return 3;

    uart_puts("[EASY] UART hello pass\r\n");
    return 0;
}
