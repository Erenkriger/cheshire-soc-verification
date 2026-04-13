// ============================================================================
// test_spm_marchc.c — CPU-side memory algorithm test inspired by DRAM BIST
//
// Runs a compact March C- style algorithm on SPM window.
// ============================================================================
#include "cheshire_util.h"

#define SPM_MARCH_BASE   (SPM_BASE + 0x0000B000UL)
#define MARCH_WORDS      16

int main(void) {
    volatile uint32_t *m = (volatile uint32_t *)SPM_MARCH_BASE;

    // M0: up write 0
    for (int i = 0; i < MARCH_WORDS; i++)
        m[i] = 0x00000000U;

    // M1: up read 0 write 1
    for (int i = 0; i < MARCH_WORDS; i++) {
        if (m[i] != 0x00000000U)
            return 1;
        m[i] = 0xFFFFFFFFU;
    }

    // M2: up read 1 write 0
    for (int i = 0; i < MARCH_WORDS; i++) {
        if (m[i] != 0xFFFFFFFFU)
            return 2;
        m[i] = 0x00000000U;
    }

    // M3: down read 0 write 1
    for (int i = MARCH_WORDS - 1; i >= 0; i--) {
        if (m[i] != 0x00000000U)
            return 3;
        m[i] = 0xFFFFFFFFU;
    }

    // M4: down read 1 write 0
    for (int i = MARCH_WORDS - 1; i >= 0; i--) {
        if (m[i] != 0xFFFFFFFFU)
            return 4;
        m[i] = 0x00000000U;
    }

    // M5: up read 0
    for (int i = 0; i < MARCH_WORDS; i++) {
        if (m[i] != 0x00000000U)
            return 5;
    }

    return 0;
}
