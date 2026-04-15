// ============================================================================
// test_lvl_medium_uart_pattern.c
// Medium-2: UART pattern streaming and line-status based pacing checks.
// ============================================================================
#include "cheshire_util.h"

#define UART_SCR 0x1C

int main(void) {
    uint32_t rtc_freq = REG32(REGS_BASE, CHS_RTC_FREQ_OFF);
    uint32_t core_freq = (rtc_freq > 0U) ? (rtc_freq * 1526U) : 50000000U;
    int scr_mismatch = 0;

    uart_init(core_freq, 115200U);
    uart_puts("[MED] UART pattern start\r\n");

    for (uint32_t i = 0; i < 128U; i++) {
        int wait;
        for (wait = 0; wait < 10000; wait++) {
            if (REG32(UART_BASE, UART_LSR) & UART_LSR_THRE)
                break;
        }
        if (wait == 10000)
            return 1;

        REG32(UART_BASE, UART_SCR) = i & 0xFFU;
        if ((REG32(UART_BASE, UART_SCR) & 0xFFU) != (i & 0xFFU))
            scr_mismatch = 1;

        uart_putc((char)('A' + (i % 26U)));
        if ((i % 32U) == 31U)
            uart_puts("\r\n");
    }

    if (scr_mismatch)
        REG32(REGS_BASE, CHS_SCRATCH1_OFF) = 0xE5020001U;

    uart_puts("[MED] UART pattern pass\r\n");
    return 0;
}
