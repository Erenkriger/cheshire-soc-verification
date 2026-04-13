// ============================================================================
// test_gpio_deep.c — CPU-side equivalent of chs_gpio_deep_vseq
//
// Covers walking patterns, masked writes, interrupt registers, and masked OE.
// ============================================================================
#include "cheshire_util.h"

static int test_walking_output(void) {
    gpio_set_output_en(0xFFFFFFFFU);
    gpio_write(0x00000000U);
    fence();

    for (int bit = 0; bit < 32; bit += 8) {
        uint32_t p = 1U << bit;
        gpio_write(p);
        fence();
        if (REG32(GPIO_BASE, GPIO_DIRECT_OUT) != p)
            return 1 + bit;
    }

    gpio_write(0x80000000U);
    fence();
    if (REG32(GPIO_BASE, GPIO_DIRECT_OUT) != 0x80000000U)
        return 40;

    gpio_write(0xFFFFFFFFU);
    fence();
    if (REG32(GPIO_BASE, GPIO_DIRECT_OUT) != 0xFFFFFFFFU)
        return 41;

    gpio_write(0x00000000U);
    return 0;
}

static int test_masked_out(void) {
    gpio_write(0x00000000U);
    fence();

    // bits[7:0] <- 0xAB
    REG32(GPIO_BASE, GPIO_MASKED_OUT_LO) = 0x00FF00ABU;
    fence();
    if ((REG32(GPIO_BASE, GPIO_DIRECT_OUT) & 0x000000FFU) != 0x000000ABU)
        return 50;

    // bits[23:16] <- 0xCD
    REG32(GPIO_BASE, GPIO_MASKED_OUT_HI) = 0x00FF00CDU;
    fence();
    if ((REG32(GPIO_BASE, GPIO_DIRECT_OUT) & 0x00FF00FFU) != 0x00CD00ABU)
        return 51;

    return 0;
}

static int test_interrupt_registers(void) {
    REG32(GPIO_BASE, GPIO_INTR_EN_RISE) = 0x0000000FU;
    REG32(GPIO_BASE, GPIO_INTR_EN_FALL) = 0x000000F0U;
    REG32(GPIO_BASE, GPIO_INTR_EN_LVLH) = 0x00000F00U;
    REG32(GPIO_BASE, GPIO_INTR_EN_LVLL) = 0x0000F000U;
    REG32(GPIO_BASE, GPIO_INTR_EN)      = 0x0000FFFFU;
    fence();

    if (REG32(GPIO_BASE, GPIO_INTR_EN_RISE) != 0x0000000FU)
        return 60;
    if (REG32(GPIO_BASE, GPIO_INTR_EN_FALL) != 0x000000F0U)
        return 61;
    if (REG32(GPIO_BASE, GPIO_INTR_EN_LVLH) != 0x00000F00U)
        return 62;
    if (REG32(GPIO_BASE, GPIO_INTR_EN_LVLL) != 0x0000F000U)
        return 63;

    // Inject interrupt via INTR_TEST and clear via W1C.
    REG32(GPIO_BASE, GPIO_INTR_TEST) = 0x00000001U;
    fence();

    uint32_t intr = REG32(GPIO_BASE, GPIO_INTR_STATE);
    if ((intr & 0x1U) == 0U)
        return 64;

    REG32(GPIO_BASE, GPIO_INTR_STATE) = intr;
    fence();

    if ((REG32(GPIO_BASE, GPIO_INTR_STATE) & 0x1U) != 0U)
        return 65;

    // Cleanup
    REG32(GPIO_BASE, GPIO_INTR_EN)      = 0x00000000U;
    REG32(GPIO_BASE, GPIO_INTR_EN_RISE) = 0x00000000U;
    REG32(GPIO_BASE, GPIO_INTR_EN_FALL) = 0x00000000U;
    REG32(GPIO_BASE, GPIO_INTR_EN_LVLH) = 0x00000000U;
    REG32(GPIO_BASE, GPIO_INTR_EN_LVLL) = 0x00000000U;

    return 0;
}

static int test_masked_oe(void) {
    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0x00000000U;
    fence();

    REG32(GPIO_BASE, GPIO_MASKED_OE_LO) = 0x000F000FU;  // enable bits[3:0]
    fence();
    if (REG32(GPIO_BASE, GPIO_DIRECT_OE) != 0x0000000FU)
        return 70;

    REG32(GPIO_BASE, GPIO_MASKED_OE_HI) = 0xFF00FF00U;  // enable bits[31:24]
    fence();
    if (REG32(GPIO_BASE, GPIO_DIRECT_OE) != 0xFF00000FU)
        return 71;

    REG32(GPIO_BASE, GPIO_DIRECT_OE) = 0x00000000U;
    REG32(GPIO_BASE, GPIO_DIRECT_OUT) = 0x00000000U;
    return 0;
}

int main(void) {
    int ret;

    ret = test_walking_output();
    if (ret) return ret;

    ret = test_masked_out();
    if (ret) return ret;

    ret = test_interrupt_registers();
    if (ret) return ret;

    ret = test_masked_oe();
    if (ret) return ret;

    return 0;
}
