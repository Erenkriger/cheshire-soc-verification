// ============================================================================
// test_lvl_medium_gpio_irq_cfg.c
// Medium-3: GPIO interrupt-related register programming and readback checks.
// ============================================================================
#include "cheshire_util.h"

int main(void) {
    const uint32_t mask_a = 0x0000000FU;
    const uint32_t mask_b = 0x000000F0U;

    REG32(GPIO_BASE, GPIO_INTR_EN_RISE) = mask_a;
    REG32(GPIO_BASE, GPIO_INTR_EN_FALL) = mask_b;
    REG32(GPIO_BASE, GPIO_INTR_EN_LVLH) = mask_a | mask_b;
    REG32(GPIO_BASE, GPIO_INTR_EN_LVLL) = 0x00000000U;
    REG32(GPIO_BASE, GPIO_INTR_EN) = 0x000000FFU;
    fence();

    if ((REG32(GPIO_BASE, GPIO_INTR_EN_RISE) & 0xFFU) != (mask_a & 0xFFU))
        return 1;
    if ((REG32(GPIO_BASE, GPIO_INTR_EN_FALL) & 0xFFU) != (mask_b & 0xFFU))
        return 2;
    if ((REG32(GPIO_BASE, GPIO_INTR_EN_LVLH) & 0xFFU) != 0xFFU)
        return 3;
    if ((REG32(GPIO_BASE, GPIO_INTR_EN) & 0xFFU) != 0xFFU)
        return 4;

    // Pulse test bits to stimulate interrupt state logic.
    REG32(GPIO_BASE, GPIO_INTR_TEST) = 0x00000003U;
    fence();

    // Clear whatever got latched (W1C style is expected for many GPIO designs).
    REG32(GPIO_BASE, GPIO_INTR_STATE) = REG32(GPIO_BASE, GPIO_INTR_STATE);
    fence();

    return 0;
}
