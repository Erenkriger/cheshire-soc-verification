// ============================================================================
// test_memory.c — Memory subsystem bare-metal test for Cheshire SoC
//
// Purpose: Verify SPM and DRAM memory integrity through write/read-back
//          tests with various data patterns (walking ones, address-as-data,
//          checkerboard, all-zeros, all-ones).
//
// Pass Criteria: All written values read back correctly.
// ============================================================================
#include "cheshire_util.h"

// Test region in SPM (use upper half to avoid code/stack)
#define SPM_TEST_BASE   (SPM_BASE + 0x8000)   // 0x10008000
#define SPM_TEST_SIZE   256                     // 256 bytes = 64 words

// Test region in DRAM
#define DRAM_TEST_BASE  (DRAM_BASE + 0x100000) // 0x80100000
#define DRAM_TEST_SIZE  256                     // 256 bytes = 64 words

static int test_region(uintptr_t base, uint32_t size_bytes, int error_base) {
    volatile uint32_t *mem = (volatile uint32_t *)base;
    uint32_t nwords = size_bytes / 4;

    // ─── Pattern 1: All zeros ───
    for (uint32_t i = 0; i < nwords; i++)
        mem[i] = 0x00000000;
    fence();
    for (uint32_t i = 0; i < nwords; i++) {
        if (mem[i] != 0x00000000)
            return error_base + 1;
    }

    // ─── Pattern 2: All ones ───
    for (uint32_t i = 0; i < nwords; i++)
        mem[i] = 0xFFFFFFFF;
    fence();
    for (uint32_t i = 0; i < nwords; i++) {
        if (mem[i] != 0xFFFFFFFF)
            return error_base + 2;
    }

    // ─── Pattern 3: Address-as-data ───
    for (uint32_t i = 0; i < nwords; i++)
        mem[i] = (uint32_t)(base + i * 4);
    fence();
    for (uint32_t i = 0; i < nwords; i++) {
        if (mem[i] != (uint32_t)(base + i * 4))
            return error_base + 3;
    }

    // ─── Pattern 4: Checkerboard ───
    for (uint32_t i = 0; i < nwords; i++)
        mem[i] = (i & 1) ? 0xAAAAAAAA : 0x55555555;
    fence();
    for (uint32_t i = 0; i < nwords; i++) {
        uint32_t expected = (i & 1) ? 0xAAAAAAAA : 0x55555555;
        if (mem[i] != expected)
            return error_base + 4;
    }

    // ─── Pattern 5: Walking ones ───
    for (uint32_t i = 0; i < 32 && i < nwords; i++)
        mem[i] = 1U << i;
    fence();
    for (uint32_t i = 0; i < 32 && i < nwords; i++) {
        if (mem[i] != (1U << i))
            return error_base + 5;
    }

    return 0;
}

int main(void) {
    int ret;

    // Test SPM region
    ret = test_region(SPM_TEST_BASE, SPM_TEST_SIZE, 10);
    if (ret) return ret;

    // Test DRAM region
    ret = test_region(DRAM_TEST_BASE, DRAM_TEST_SIZE, 20);
    if (ret) return ret;

    // All tests passed
    return 0;
}
