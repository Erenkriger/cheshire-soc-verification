// ============================================================================
// cheshire_util.h — Bare-metal utilities for Cheshire SoC verification tests
// Minimal standalone header — no dependency on Cheshire SDK
// ============================================================================
#ifndef CHESHIRE_UTIL_H
#define CHESHIRE_UTIL_H

#include <stdint.h>

// ═══════════════════════════════════════════════
// Memory Map — Cheshire SoC Peripheral Base Addresses
// ═══════════════════════════════════════════════
#define REGS_BASE      0x03000000UL   // Cheshire control/status registers
#define LLC_BASE       0x03001000UL   // Last-Level Cache control
#define UART_BASE      0x03002000UL   // UART (16550-compatible)
#define I2C_BASE       0x03003000UL   // I2C controller (OpenTitan)
#define SPI_BASE       0x03004000UL   // SPI Host controller (OpenTitan)
#define GPIO_BASE      0x03005000UL   // GPIO controller
#define SLINK_BASE     0x03006000UL   // Serial Link
#define VGA_BASE       0x03007000UL   // VGA controller
#define USB_BASE       0x03008000UL   // USB OHCI controller
#define CLINT_BASE     0x02040000UL   // CLINT (timer/SW interrupts)
#define PLIC_BASE      0x04000000UL   // PLIC (interrupt controller)
#define SPM_BASE       0x10000000UL   // LLC SPM window (64 MiB)
#define DRAM_BASE      0x80000000UL   // External DRAM (via LLC)
#define BOOTROM_BASE   0x02000000UL   // Boot ROM

// ═══════════════════════════════════════════════
// Cheshire Register Offsets
// ═══════════════════════════════════════════════
#define CHS_SCRATCH0_OFF   0x00
#define CHS_SCRATCH1_OFF   0x04
#define CHS_SCRATCH2_OFF   0x08   // End-of-computation register
#define CHS_SCRATCH3_OFF   0x0C
#define CHS_BOOT_MODE_OFF  0x10
#define CHS_RTC_FREQ_OFF   0x14
#define CHS_PLATFORM_OFF   0x18
#define CHS_NUM_INT_OFF    0x1C
#define CHS_HW_FEATURES_OFF 0x20

// ═══════════════════════════════════════════════
// UART Registers (16550-compatible)
// ═══════════════════════════════════════════════
#define UART_THR     0x00   // Transmit Holding Register (W)
#define UART_RBR     0x00   // Receive Buffer Register (R)
#define UART_IER     0x04   // Interrupt Enable Register
#define UART_FCR     0x08   // FIFO Control Register (W)
#define UART_LCR     0x0C   // Line Control Register
#define UART_MCR     0x10   // Modem Control Register
#define UART_LSR     0x14   // Line Status Register
#define UART_DLL     0x00   // Divisor Latch Low (when DLAB=1)
#define UART_DLH     0x04   // Divisor Latch High (when DLAB=1)

#define UART_LSR_THRE  (1 << 5)  // THR Empty
#define UART_LSR_DR    (1 << 0)  // Data Ready
#define UART_LCR_DLAB  (1 << 7)  // Divisor Latch Access Bit

// ═══════════════════════════════════════════════
// GPIO Registers
// ═══════════════════════════════════════════════
#define GPIO_DATA_IN      0x10
#define GPIO_DIRECT_OUT   0x14
#define GPIO_MASKED_OUT_LO 0x18
#define GPIO_MASKED_OUT_HI 0x1C
#define GPIO_DIRECT_OE    0x20
#define GPIO_MASKED_OE_LO 0x24
#define GPIO_MASKED_OE_HI 0x28
#define GPIO_INTR_STATE   0x00
#define GPIO_INTR_EN      0x04
#define GPIO_INTR_TEST    0x08
#define GPIO_INTR_EN_RISE 0x2C
#define GPIO_INTR_EN_FALL 0x30
#define GPIO_INTR_EN_LVLH 0x34
#define GPIO_INTR_EN_LVLL 0x38

// ═══════════════════════════════════════════════
// SPI Host Registers (OpenTitan SPI Host)
// ═══════════════════════════════════════════════
#define SPI_CTRL        0x10
#define SPI_STATUS      0x14
#define SPI_CONFIGOPTS0 0x18
#define SPI_CSID        0x24
#define SPI_COMMAND     0x28
#define SPI_RXDATA      0x2C
#define SPI_TXDATA      0x30
#define SPI_ERR_ENABLE  0x34
#define SPI_ERR_STATUS  0x38
#define SPI_EVT_ENABLE  0x3C
#define SPI_CONTROL     0x10

#define SPI_STATUS_RXEMPTY (1u << 24)
#define SPI_STATUS_TXEMPTY (1u << 28)
#define SPI_STATUS_ACTIVE  (1u << 30)
#define SPI_STATUS_READY   (1u << 31)

// ═══════════════════════════════════════════════
// I2C Registers (OpenTitan I2C)
// ═══════════════════════════════════════════════
#define I2C_INTR_STATE 0x00
#define I2C_INTR_EN   0x04
#define I2C_CTRL      0x10
#define I2C_STATUS    0x14
#define I2C_RXFIFO    0x18
#define I2C_FMTFIFO   0x1C
#define I2C_FIFO_CTRL 0x20
#define I2C_FIFO_STATUS 0x24
#define I2C_OVRD      0x28
#define I2C_VAL       0x2C
#define I2C_TIMING0   0x30
#define I2C_TIMING1   0x34
#define I2C_TIMING2   0x38
#define I2C_TIMING3   0x3C
#define I2C_TIMING4   0x40
#define I2C_TIMEOUT_CTRL 0x44

#define I2C_STATUS_FMTEMPTY (1u << 2)
#define I2C_STATUS_HOSTIDLE (1u << 3)

// ═══════════════════════════════════════════════
// MMIO Access Macros
// ═══════════════════════════════════════════════
#define REG32(base, off)  (*(volatile uint32_t *)((uintptr_t)(base) + (off)))
#define REG8(base, off)   (*(volatile uint8_t  *)((uintptr_t)(base) + (off)))

// ═══════════════════════════════════════════════
// UART Functions (Inline)
// ═══════════════════════════════════════════════
static inline void uart_init(uint32_t core_freq, uint32_t baud) {
    uint32_t divisor = core_freq / (baud << 4);
    REG32(UART_BASE, UART_IER) = 0;           // Disable interrupts
    REG32(UART_BASE, UART_LCR) = UART_LCR_DLAB; // Enable DLAB
    REG32(UART_BASE, UART_DLL) = divisor & 0xFF;
    REG32(UART_BASE, UART_DLH) = (divisor >> 8) & 0xFF;
    REG32(UART_BASE, UART_LCR) = 0x03;        // 8N1, DLAB off
    REG32(UART_BASE, UART_FCR) = 0x07;        // Enable FIFO, reset
}

static inline void uart_putc(char c) {
    while (!(REG32(UART_BASE, UART_LSR) & UART_LSR_THRE))
        ;
    REG32(UART_BASE, UART_THR) = c;
}

static inline void uart_puts(const char *s) {
    while (*s)
        uart_putc(*s++);
}

static inline void uart_put_hex32(uint32_t val) {
    const char hex[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4)
        uart_putc(hex[(val >> i) & 0xF]);
}

// ═══════════════════════════════════════════════
// GPIO Functions (Inline)
// ═══════════════════════════════════════════════
static inline void gpio_set_output_en(uint32_t mask) {
    REG32(GPIO_BASE, GPIO_DIRECT_OE) = mask;
}

static inline void gpio_write(uint32_t val) {
    REG32(GPIO_BASE, GPIO_DIRECT_OUT) = val;
}

static inline uint32_t gpio_read(void) {
    return REG32(GPIO_BASE, GPIO_DATA_IN);
}

// ═══════════════════════════════════════════════
// Memory Fence
// ═══════════════════════════════════════════════
static inline void fence(void) {
    asm volatile ("fence" ::: "memory");
}

// ═══════════════════════════════════════════════
// End-of-computation signal
// Already handled by _exit in crt0.S, but can be
// called explicitly for early termination.
// ═══════════════════════════════════════════════
static inline void signal_eoc(int retval) {
    REG32(REGS_BASE, CHS_SCRATCH2_OFF) = (retval << 1) | 1;
}

#endif // CHESHIRE_UTIL_H
