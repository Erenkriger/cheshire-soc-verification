// ============================================================================
// test_lvl_hard_idma_multi_copy.c
// Hard-1: Multiple iDMA transfers with varying lengths and buffer offsets.
// ============================================================================
#include "cheshire_util.h"

#define IDMA_BASE           0x01000000UL
#define IDMA_CONF_OFF       0x00
#define IDMA_NEXT_ID_0_OFF  0x44
#define IDMA_DONE_ID_0_OFF  0x84
#define IDMA_DST_ADDR_LO    0xD0
#define IDMA_DST_ADDR_HI    0xD4
#define IDMA_SRC_ADDR_LO    0xD8
#define IDMA_SRC_ADDR_HI    0xDC
#define IDMA_LENGTH_LO      0xE0
#define IDMA_LENGTH_HI      0xE4
#define IDMA_DST_STRIDE_LO  0xE8
#define IDMA_DST_STRIDE_HI  0xEC
#define IDMA_SRC_STRIDE_LO  0xF0
#define IDMA_SRC_STRIDE_HI  0xF4
#define IDMA_REPS_LO        0xF8
#define IDMA_REPS_HI        0xFC

#define IDMA_SRC_BASE       (SPM_BASE + 0x00018000UL)
#define IDMA_DST_BASE       (SPM_BASE + 0x0001A000UL)

static inline uint32_t idma_rd(uint32_t off) {
    return REG32(IDMA_BASE, off);
}

static inline void idma_wr(uint32_t off, uint32_t val) {
    REG32(IDMA_BASE, off) = val;
}

int main(void) {
    volatile uint32_t *src = (volatile uint32_t *)IDMA_SRC_BASE;
    volatile uint32_t *dst = (volatile uint32_t *)IDMA_DST_BASE;

    for (int round = 0; round < 3; round++) {
        int words = 16 + (round * 8);
        uintptr_t src_addr = IDMA_SRC_BASE + (uintptr_t)(round * 0x100);
        uintptr_t dst_addr = IDMA_DST_BASE + (uintptr_t)(round * 0x100);
        uint32_t launch_id;
        int done = 0;

        for (int i = 0; i < words; i++) {
            src[(round * 64) + i] = (0xC0000000U + ((uint32_t)round << 20)) + (uint32_t)i;
            dst[(round * 64) + i] = 0x0U;
        }
        fence();

        idma_wr(IDMA_SRC_ADDR_LO, (uint32_t)src_addr);
        idma_wr(IDMA_SRC_ADDR_HI, 0x0U);
        idma_wr(IDMA_DST_ADDR_LO, (uint32_t)dst_addr);
        idma_wr(IDMA_DST_ADDR_HI, 0x0U);
        idma_wr(IDMA_LENGTH_LO, (uint32_t)(words * 4));
        idma_wr(IDMA_LENGTH_HI, 0x0U);
        idma_wr(IDMA_SRC_STRIDE_LO, 0x0U);
        idma_wr(IDMA_SRC_STRIDE_HI, 0x0U);
        idma_wr(IDMA_DST_STRIDE_LO, 0x0U);
        idma_wr(IDMA_DST_STRIDE_HI, 0x0U);
        idma_wr(IDMA_REPS_LO, 1U);
        idma_wr(IDMA_REPS_HI, 0x0U);
        idma_wr(IDMA_CONF_OFF, 0x00000002U);

        launch_id = idma_rd(IDMA_NEXT_ID_0_OFF);

        for (int i = 0; i < 300000; i++) {
            if (idma_rd(IDMA_DONE_ID_0_OFF) == launch_id) {
                done = 1;
                break;
            }
        }

        if (!done)
            return 1 + round;

        for (int i = 0; i < words; i++) {
            uint32_t exp = (0xC0000000U + ((uint32_t)round << 20)) + (uint32_t)i;
            if (dst[(round * 64) + i] != exp)
                return 20 + (round * 8) + i;
        }
    }

    return 0;
}
