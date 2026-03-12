// ============================================================================
// test_gpio.c — GPIO peripheral bare-metal test for Cheshire SoC
//
// Purpose: Verify GPIO output enable, write, and read-back functionality
//          by exercising the GPIO controller's MMIO registers directly.
//
// Pass Criteria: GPIO OE and output register values match expected patterns.
// ============================================================================
#include "cheshire_util.h"

static int test_gpio_output_enable(void) {
    // Set all 32 GPIOs as outputs
    gpio_set_output_en(0xFFFFFFFF);
    fence();

    uint32_t oe_val = REG32(GPIO_BASE, GPIO_DIRECT_OE);
    if (oe_val != 0xFFFFFFFF)
        return 1;

    // Set lower 16 as outputs
    gpio_set_output_en(0x0000FFFF);
    fence();

    oe_val = REG32(GPIO_BASE, GPIO_DIRECT_OE);
    if (oe_val != 0x0000FFFF)
        return 2;

    return 0;
}

static int test_gpio_write_read(void) {
    // Enable all outputs
    gpio_set_output_en(0xFFFFFFFF);
    fence();

    // Walking ones test
    for (int i = 0; i < 32; i++) {
        uint32_t pattern = 1U << i;
        gpio_write(pattern);
        fence();

        uint32_t readback = REG32(GPIO_BASE, GPIO_DIRECT_OUT);
        if (readback != pattern)
            return 10 + i;
    }

    // All zeros
    gpio_write(0x00000000);
    fence();
    if (REG32(GPIO_BASE, GPIO_DIRECT_OUT) != 0x00000000)
        return 50;

    // All ones
    gpio_write(0xFFFFFFFF);
    fence();
    if (REG32(GPIO_BASE, GPIO_DIRECT_OUT) != 0xFFFFFFFF)
        return 51;

    // Checkerboard patterns
    gpio_write(0x55555555);
    fence();
    if (REG32(GPIO_BASE, GPIO_DIRECT_OUT) != 0x55555555)
        return 52;

    gpio_write(0xAAAAAAAA);
    fence();
    if (REG32(GPIO_BASE, GPIO_DIRECT_OUT) != 0xAAAAAAAA)
        return 53;

    return 0;
}

int main(void) {
    int ret;

    ret = test_gpio_output_enable();
    if (ret) return ret;

    ret = test_gpio_write_read();
    if (ret) return ret;

    // All tests passed
    return 0;
}
