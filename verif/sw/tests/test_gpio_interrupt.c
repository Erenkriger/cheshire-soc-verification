// ============================================================================
// test_gpio_interrupt.c — CPU-side equivalent of chs_interrupt_vseq
//
// Configures GPIO interrupt controls, triggers via edge and INTR_TEST fallback,
// then verifies W1C clear path.
// ============================================================================
#include "cheshire_util.h"

static int wait_for_intr0(int max_poll) {
    for (int i = 0; i < max_poll; i++) {
        uint32_t v = REG32(GPIO_BASE, GPIO_INTR_STATE);
        if (v & 0x1U)
            return 0;
    }
    return -1;
}

int main(void) {
    // Clean start
    REG32(GPIO_BASE, GPIO_INTR_STATE) = 0xFFFFFFFFU;
    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0x00000001U;
    REG32(GPIO_BASE, GPIO_DIRECT_OUT) = 0x00000000U;

    REG32(GPIO_BASE, GPIO_INTR_EN_RISE) = 0x00000001U;
    REG32(GPIO_BASE, GPIO_INTR_EN_FALL) = 0x00000000U;
    REG32(GPIO_BASE, GPIO_INTR_EN) = 0x00000001U;
    fence();

    if (REG32(GPIO_BASE, GPIO_INTR_EN_RISE) != 0x00000001U)
        return 1;

    // Try natural edge trigger first.
    REG32(GPIO_BASE, GPIO_DIRECT_OUT) = 0x00000001U;
    fence();

    if (wait_for_intr0(2000) != 0) {
        // Some configs do not loop GPIO output back to input, so force trigger.
        REG32(GPIO_BASE, GPIO_INTR_TEST) = 0x00000001U;
        fence();
        if (wait_for_intr0(2000) != 0)
            return 2;
    }

    // W1C clear
    REG32(GPIO_BASE, GPIO_INTR_STATE) = 0x00000001U;
    fence();

    if (REG32(GPIO_BASE, GPIO_INTR_STATE) & 0x1U)
        return 3;

    // Bonus: falling edge config register check on bit1
    REG32(GPIO_BASE, GPIO_INTR_EN_FALL) = 0x00000002U;
    fence();
    if ((REG32(GPIO_BASE, GPIO_INTR_EN_FALL) & 0x2U) == 0U)
        return 4;

    // Cleanup
    REG32(GPIO_BASE, GPIO_INTR_EN) = 0x00000000U;
    REG32(GPIO_BASE, GPIO_INTR_EN_RISE) = 0x00000000U;
    REG32(GPIO_BASE, GPIO_INTR_EN_FALL) = 0x00000000U;
    REG32(GPIO_BASE, GPIO_DIRECT_OUT) = 0x00000000U;
    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0x00000000U;

    return 0;
}
