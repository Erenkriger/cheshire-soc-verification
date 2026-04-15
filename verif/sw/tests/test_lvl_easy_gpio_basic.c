// ============================================================================
// test_lvl_easy_gpio_basic.c
// Easy-2: GPIO output-enable/output smoke with deterministic patterns.
// ============================================================================
#include "cheshire_util.h"

int main(void) {
    const uint32_t patterns[6] = {
        0x00000000U,
        0x00000001U,
        0x000000A5U,
        0x00005AA5U,
        0x0000FFFFU,
        0x00001234U
    };

    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0x0000FFFFU;
    fence();

    if ((REG32(GPIO_BASE, GPIO_DIRECT_OE) & 0x0000FFFFU) != 0x0000FFFFU)
        return 1;

    for (int i = 0; i < 6; i++) {
        REG32(GPIO_BASE, GPIO_DIRECT_OUT) = patterns[i];
        fence();
        if ((REG32(GPIO_BASE, GPIO_DIRECT_OUT) & 0x0000FFFFU) != (patterns[i] & 0x0000FFFFU))
            return 10 + i;
    }

    return 0;
}
