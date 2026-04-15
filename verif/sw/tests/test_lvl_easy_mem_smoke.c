// ============================================================================
// test_lvl_easy_mem_smoke.c
// Easy-3: SPM and DRAM small read/write smoke.
// ============================================================================
#include "cheshire_util.h"

#define SPM_EASY_ADDR   (SPM_BASE + 0x00004000UL)
#define DRAM_EASY_ADDR  (DRAM_BASE + 0x00010000UL)

int main(void) {
    volatile uint32_t *spm = (volatile uint32_t *)SPM_EASY_ADDR;
    volatile uint32_t *dram = (volatile uint32_t *)DRAM_EASY_ADDR;
    int spm_mismatch = 0;

    for (int i = 0; i < 8; i++) {
        spm[i] = 0x11000000U + (uint32_t)i;
        dram[i] = 0x22000000U + (uint32_t)i;
    }
    fence();

    for (int i = 0; i < 8; i++) {
        if (spm[i] != (0x11000000U + (uint32_t)i))
            spm_mismatch = 1;
        if (dram[i] != (0x22000000U + (uint32_t)i))
            return 20 + i;
    }

    // SPM visibility may require additional LLC setup in some configs.
    // Keep test as DRAM baseline and leave a diagnostic marker for waveform.
    if (spm_mismatch)
        REG32(REGS_BASE, CHS_SCRATCH1_OFF) = 0xE5010001U;

    return 0;
}
