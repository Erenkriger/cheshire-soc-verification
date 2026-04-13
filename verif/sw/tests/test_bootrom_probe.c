// ============================================================================
// test_bootrom_probe.c — CPU-side equivalent of chs_bootrom_fetch_vseq (probe)
//
// Probes BootROM content and SoC control registers from firmware context.
// ============================================================================
#include "cheshire_util.h"

int main(void) {
    uint32_t nonzero = 0;
    uint32_t xacc = 0;

    for (int i = 0; i < 32; i++) {
        uint32_t w = REG32(BOOTROM_BASE, (uint32_t)(i * 4));
        xacc ^= w;
        if (w != 0U)
            nonzero++;
    }

    if (nonzero < 4U)
        return 1;
    if (xacc == 0U)
        return 2;

    // Basic SoC register access around boot context.
    uint32_t platform = REG32(REGS_BASE, CHS_PLATFORM_OFF);
    uint32_t num_int = REG32(REGS_BASE, CHS_NUM_INT_OFF);
    uint32_t features = REG32(REGS_BASE, CHS_HW_FEATURES_OFF);

    if ((platform | num_int | features) == 0U)
        return 3;

    // Scratch path for software-visible end-to-end check.
    REG32(REGS_BASE, CHS_SCRATCH0_OFF) = 0xB007B007U;
    REG32(REGS_BASE, CHS_SCRATCH1_OFF) = 0xF00DF00DU;
    fence();

    if (REG32(REGS_BASE, CHS_SCRATCH0_OFF) != 0xB007B007U)
        return 4;
    if (REG32(REGS_BASE, CHS_SCRATCH1_OFF) != 0xF00DF00DU)
        return 5;

    return 0;
}
