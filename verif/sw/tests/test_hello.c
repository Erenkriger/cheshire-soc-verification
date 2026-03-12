// ============================================================================
// test_hello.c — Basic "Hello World" bare-metal test for Cheshire SoC
//
// Purpose: Verify that the CVA6 processor can boot, execute C code, initialize
//          the UART peripheral, and send characters to the serial port.
//          This is the most basic SW-driven verification test.
//
// Pass Criteria: UART TX output contains "HELLO" string, return 0 → EOC=1
// ============================================================================
#include "cheshire_util.h"

int main(void) {
    // Read RTC frequency from Cheshire registers
    uint32_t rtc_freq = REG32(REGS_BASE, CHS_RTC_FREQ_OFF);

    // Simple frequency estimation: assume ~50 MHz if rtc_freq is reasonable
    uint32_t core_freq = (rtc_freq > 0) ? rtc_freq * 1526 : 50000000;

    // Initialize UART at 115200 baud
    uart_init(core_freq, 115200);

    // Send test string
    uart_puts("HELLO CHESHIRE SOC!\r\n");

    // Send hex test pattern
    uart_puts("SCRATCH0: ");
    uart_put_hex32(REG32(REGS_BASE, CHS_SCRATCH0_OFF));
    uart_puts("\r\n");

    // Return 0 → success (crt0 _exit writes 0x1 to SCRATCH[2])
    return 0;
}
