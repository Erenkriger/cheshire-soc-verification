// ============================================================================
// test_lvl_extreme_sys_bench.c
// ============================================================================
// ULTIMATE SOC-LEVEL EXTREME BENCHMARK Test
// Stresses: Memory (DRAM/SPM), AXI Interconnect, APB Peripherals (UART, GPIO, I2C, SPI), 
// ALU (Matrix mult), Branch Predictor (Recursion/Hanoi)
// ============================================================================
#include "cheshire_util.h"

// Scaled iterations for heavy stress
#define MATRIX_SIZE 24
#define HANOI_DISKS 9
#define MEM_BLOCK_SIZE 2048 // 32-bit words

// Timeout for UART to prevent indefinite hangs
#define UART_TIMEOUT_CYCLES 50000

// Memory pointers
uint32_t *dram_buffer = (uint32_t *)DRAM_BASE; 
uint32_t *spm_buffer  = (uint32_t *)SPM_BASE;

// ---------------------------------------------------------
// Robust UART Logging (Fail-safe)
// ---------------------------------------------------------
void safe_uart_putc(char c) {
    uint32_t timeout = 0;
    while (!(REG32(UART_BASE, 0x14) & 0x20)) { // Wait for TX idle
        timeout++;
        if (timeout > UART_TIMEOUT_CYCLES) return; // Drop char on timeout
    }
    REG32(UART_BASE, 0x00) = c;
}

void safe_print_str(const char *str) {
    while (*str) {
        safe_uart_putc(*str++);
    }
}

void safe_print_hex(uint32_t val) {
    const char hex_chars[] = "0123456789ABCDEF";
    safe_print_str("0x");
    for (int i = 28; i >= 0; i -= 4) {
        safe_uart_putc(hex_chars[(val >> i) & 0xF]);
    }
}

static inline void mark_progress(uint32_t scratch_idx, uint32_t val) {
    REG32(REGS_BASE, scratch_idx) = val;
    fence();
}

static inline uint64_t read_cycle() {
    uint64_t cycle;
    asm volatile ("rdcycle %0" : "=r" (cycle));
    return cycle;
}

// ---------------------------------------------------------
// 1. Peripheral Stress Pings (APB Bus load)
// ---------------------------------------------------------
void ping_peripherals(uint32_t iteration) {
    // Write patterns to GPIO, I2C config, SPI config (just writing to scratch/status registers or safe configs without triggering real external comms to test APB decoding)
    REG32(GPIO_BASE, 0x14) = iteration; // GPIO_DIRECT_OUT
    REG32(I2C_BASE, 0x04) = 0;          // I2C_INTR_EN = 0
    REG32(SPI_BASE, 0x34) = 0;          // SPI_ERR_ENABLE = 0

    // Dummy reads ensuring bus turnaround
    volatile uint32_t dummy = 0;
    dummy ^= REG32(GPIO_BASE, 0x10);    // GPIO_DATA_IN
    dummy ^= REG32(I2C_BASE, 0x14);     // I2C_STATUS
    dummy ^= REG32(SPI_BASE, 0x14);     // SPI_STATUS
    (void)dummy;
    fence();
}

// ---------------------------------------------------------
// 2. Matrix Multiplication (ALU + Memory Stripe Store)
// ---------------------------------------------------------
void multiply_matrices() {
    for(uint32_t i=0; i<MATRIX_SIZE; i++) {
        for(uint32_t j=0; j<MATRIX_SIZE; j++) {
            uint32_t sum = 0;
            for(uint32_t k=0; k<MATRIX_SIZE; k++) {
                sum += dram_buffer[i*MATRIX_SIZE + k] * dram_buffer[k*MATRIX_SIZE + j];
            }
            dram_buffer[(MATRIX_SIZE*MATRIX_SIZE) + i*MATRIX_SIZE + j] = sum;
            // Interleave peripheral accesses to congest memory & peripheral bus simultaneously
            ping_peripherals(i * j);
        }
    }
}

// ---------------------------------------------------------
// 3. Branches & Stack Stress
// ---------------------------------------------------------
volatile uint32_t hanoi_moves = 0;
void solve_hanoi(int n, int from, int to, int aux) {
    if (n == 1) {
        hanoi_moves++;
        // Stack intensive memory operation
        spm_buffer[hanoi_moves % 1024] = spm_buffer[(hanoi_moves - 1) % 1024] ^ n;
        ping_peripherals(hanoi_moves);
        return;
    }
    solve_hanoi(n - 1, from, aux, to);
    hanoi_moves++;
    solve_hanoi(n - 1, aux, to, from);
}

// ---------------------------------------------------------
// 4. Memory Sweep + CRC32
// ---------------------------------------------------------
uint32_t calc_crc32(uint32_t *data, uint32_t length) {
    uint32_t crc = 0xFFFFFFFF;
    for(uint32_t i=0; i<length; i++) {
        uint32_t word = data[i];
        crc = crc ^ word;
        for(int j=0; j<32; j++) {
            if (crc & 1) crc = (crc >> 1) ^ 0xEDB88320;
            else         crc = (crc >> 1);
        }
        if((i % 64) == 0) ping_peripherals(i); // Periodic peripheral congestion
    }
    return crc ^ 0xFFFFFFFF;
}

// ---------------------------------------------------------
// MAIN EXTREME FLOW
// ---------------------------------------------------------
int main(void) {
    // 0. Initialize UART securely
    // Assume 50MHz reset freq, 115200 baud
    uart_init(50000000, 115200);

    mark_progress(CHS_SCRATCH0_OFF, 0x11111111); // Stage 1 started
    safe_print_str("\r\n[SYS_BENCH_EXTREME] Starting Massive System Check...\r\n");

    uint64_t g_start, g_end;
    g_start = read_cycle();

    // ---------------------------------------
    // STAGE 1: Matrix Multi (DRAM Initialization & Compute)
    // ---------------------------------------
    safe_print_str("[SYS_BENCH_EXTREME] STAGE 1 (ALU & DRAM Bus)...\r\n");
    for(uint32_t i=0; i<MATRIX_SIZE*MATRIX_SIZE; i++) {
        dram_buffer[i] = i ^ 0xCAFEBABE; // Setup initial matrices A and B in DRAM
    }
    fence();
    multiply_matrices();
    mark_progress(CHS_SCRATCH0_OFF, 0x22222222); // Stage 2 started

    // ---------------------------------------
    // STAGE 2: Towers of Hanoi (Branching, Stack, SPM)
    // ---------------------------------------
    safe_print_str("[SYS_BENCH_EXTREME] STAGE 2 (Branching & SPM Stack)...\r\n");
    spm_buffer[0] = 0xAA55AA55;
    solve_hanoi(HANOI_DISKS, 1, 3, 2);
    mark_progress(CHS_SCRATCH0_OFF, 0x33333333); // Stage 3 started

    // ---------------------------------------
    // STAGE 3: Memory Sweep CRC (DRAM->SPM DMA/Loop emulation)
    // ---------------------------------------
    safe_print_str("[SYS_BENCH_EXTREME] STAGE 3 (Memory Bus Sweep & CRC)...\r\n");
    for(uint32_t i=0; i<MEM_BLOCK_SIZE; i++) {
        dram_buffer[i] = 0xDEADBEEF ^ i; 
    }
    fence();
    
    // Manual pseudo-DMA copy: DRAM to SPM
    for(uint32_t i=0; i<MEM_BLOCK_SIZE; i++) {
        spm_buffer[i] = dram_buffer[i];
    }
    fence();

    uint32_t final_crc = calc_crc32(spm_buffer, MEM_BLOCK_SIZE);
    
    g_end = read_cycle();

    safe_print_str("   CRC32 : "); safe_print_hex(final_crc); safe_print_str("\r\n");
    safe_print_str("   HANOI : "); safe_print_hex(hanoi_moves); safe_print_str("\r\n");
    safe_print_str("   CYCLES: "); safe_print_hex((uint32_t)(g_end - g_start)); safe_print_str("\r\n");

    // All passing if we reached here!
    mark_progress(CHS_SCRATCH0_OFF, 0x99999999);
    safe_print_str("[SYS_BENCH_EXTREME] PASS.\r\n");
    
    // crt0.S tracks `return 0;` and places `1` into SCRATCH2 as True EOC.
    return 0; 
}
