// ============================================================================
// test_lvl_hard_spm_dram_march_mix.c
// Hard-2: March-like algorithm on both SPM and DRAM windows.
// ============================================================================
#include "cheshire_util.h"

#define SPM_MARCH_ADDR   (SPM_BASE + 0x00024000UL)
#define DRAM_MARCH_ADDR  (DRAM_BASE + 0x00030000UL)
#define MARCH_WORDS      64

static int march_region(volatile uint32_t *m, uint32_t p0, uint32_t p1) {
    for (int i = 0; i < MARCH_WORDS; i++)
        m[i] = p0;

    for (int i = 0; i < MARCH_WORDS; i++) {
        if (m[i] != p0)
            return 1;
        m[i] = p1;
    }

    for (int i = MARCH_WORDS - 1; i >= 0; i--) {
        if (m[i] != p1)
            return 2;
        m[i] = p0;
    }

    for (int i = 0; i < MARCH_WORDS; i++) {
        if (m[i] != p0)
            return 3;
    }

    return 0;
}

int main(void) {
    volatile uint32_t *spm = (volatile uint32_t *)SPM_MARCH_ADDR;
    volatile uint32_t *dram = (volatile uint32_t *)DRAM_MARCH_ADDR;
    int ret;

    ret = march_region(spm, 0x00000000U, 0xFFFFFFFFU);
    if (ret)
        return 10 + ret;

    ret = march_region(dram, 0x5555AAAAU, 0xAAAA5555U);
    if (ret)
        return 20 + ret;

    for (int i = 0; i < MARCH_WORDS; i++)
        dram[i] = spm[i] ^ 0x13579BDFU;

    fence();

    for (int i = 0; i < MARCH_WORDS; i++) {
        uint32_t exp = spm[i] ^ 0x13579BDFU;
        if (dram[i] != exp)
            return 40 + i;
    }

    return 0;
}
