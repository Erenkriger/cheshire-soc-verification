// ============================================================================
// test_idma_basic.c — CPU-side equivalent of chs_idma_vseq
//
// Programs iDMA for one 1D transfer from SPM source to SPM destination.
// ============================================================================
#include "cheshire_util.h"

#define IDMA_BASE           0x01000000UL
#define IDMA_CONF_OFF       0x00
#define IDMA_STATUS_0_OFF   0x04
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

#define IDMA_SRC_BASE       (SPM_BASE + 0x0000C000UL)
#define IDMA_DST_BASE       (SPM_BASE + 0x0000D000UL)

static inline uint32_t idma_rd(uint32_t off) {
    return REG32(IDMA_BASE, off);
}

static inline void idma_wr(uint32_t off, uint32_t val) {
    REG32(IDMA_BASE, off) = val;
}

int main(void) {
    volatile uint32_t *src = (volatile uint32_t *)IDMA_SRC_BASE;
    volatile uint32_t *dst = (volatile uint32_t *)IDMA_DST_BASE;

    for (int i = 0; i < 16; i++) {
        src[i] = 0xCAFE0000U + (uint32_t)i;
        dst[i] = 0x00000000U;
    }
    fence();

    // Configure 1D transfer of 64 bytes.
    idma_wr(IDMA_SRC_ADDR_LO, (uint32_t)IDMA_SRC_BASE);
    idma_wr(IDMA_SRC_ADDR_HI, 0x0U);
    idma_wr(IDMA_DST_ADDR_LO, (uint32_t)IDMA_DST_BASE);
    idma_wr(IDMA_DST_ADDR_HI, 0x0U);
    idma_wr(IDMA_LENGTH_LO, 64U);
    idma_wr(IDMA_LENGTH_HI, 0x0U);

    idma_wr(IDMA_SRC_STRIDE_LO, 0x0U);
    idma_wr(IDMA_SRC_STRIDE_HI, 0x0U);
    idma_wr(IDMA_DST_STRIDE_LO, 0x0U);
    idma_wr(IDMA_DST_STRIDE_HI, 0x0U);
    idma_wr(IDMA_REPS_LO, 1U);
    idma_wr(IDMA_REPS_HI, 0x0U);

    // decouple_rw=1, nd disabled.
    idma_wr(IDMA_CONF_OFF, 0x00000002U);

    // Reading NEXT_ID launches transfer.
    uint32_t launch_id = idma_rd(IDMA_NEXT_ID_0_OFF);
    (void)idma_rd(IDMA_STATUS_0_OFF);

    int done = 0;
    for (int i = 0; i < 200000; i++) {
        uint32_t done_id = idma_rd(IDMA_DONE_ID_0_OFF);
        if (done_id == launch_id) {
            done = 1;
            break;
        }
    }

    if (!done)
        return 1;

    for (int i = 0; i < 16; i++) {
        uint32_t exp = 0xCAFE0000U + (uint32_t)i;
        if (dst[i] != exp)
            return 10 + i;
    }

    return 0;
}
