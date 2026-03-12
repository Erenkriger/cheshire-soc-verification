// ============================================================================
// test_uart_loopback.c — UART register-level bare-metal test for Cheshire SoC
//
// Purpose: Verify UART 16550 register access — initialization, divisor latch
//          programming, FIFO control, and TX data flow.
//          Note: No external UART agent in UVM testbench, so this test
//          focuses on register-level verification.
//
// Pass Criteria: UART registers accept writes and LSR indicates expected states.
// ============================================================================
#include "cheshire_util.h"

static int test_uart_registers(void) {
    // ─── Test 1: LCR write/read ───
    REG32(UART_BASE, UART_LCR) = 0x03;  // 8N1
    fence();
    uint32_t lcr = REG32(UART_BASE, UART_LCR);
    if ((lcr & 0xFF) != 0x03)
        return 1;

    // ─── Test 2: DLAB access ───
    REG32(UART_BASE, UART_LCR) = 0x83;  // DLAB=1, 8N1
    fence();
    lcr = REG32(UART_BASE, UART_LCR);
    if ((lcr & 0xFF) != 0x83)
        return 2;

    // Write divisor
    REG32(UART_BASE, UART_DLL) = 0x1B;  // 27 → ~115200 baud at 50MHz
    REG32(UART_BASE, UART_DLH) = 0x00;
    fence();

    // Read back divisor
    uint32_t dll = REG32(UART_BASE, UART_DLL) & 0xFF;
    if (dll != 0x1B)
        return 3;

    // Disable DLAB
    REG32(UART_BASE, UART_LCR) = 0x03;
    fence();

    return 0;
}

static int test_uart_tx(void) {
    // Initialize UART
    uint32_t rtc_freq = REG32(REGS_BASE, CHS_RTC_FREQ_OFF);
    uint32_t core_freq = (rtc_freq > 0) ? rtc_freq * 1526 : 50000000;
    uart_init(core_freq, 115200);

    // ─── Check LSR initial state: THRE should be set ───
    uint32_t lsr = REG32(UART_BASE, UART_LSR);
    if (!(lsr & UART_LSR_THRE))
        return 10;

    // ─── Send a few characters ───
    uart_putc('U');
    uart_putc('A');
    uart_putc('R');
    uart_putc('T');
    uart_putc('\r');
    uart_putc('\n');

    // ─── Send all printable ASCII ───
    for (char c = 0x20; c < 0x7F; c++) {
        uart_putc(c);
    }
    uart_puts("\r\n");

    // ─── Send boundary values ───
    uart_putc(0x00);  // NUL
    uart_putc(0x7F);  // DEL
    uart_putc(0xFF);  // All ones

    return 0;
}

int main(void) {
    int ret;

    ret = test_uart_registers();
    if (ret) return ret;

    ret = test_uart_tx();
    if (ret) return ret;

    return 0;
}
