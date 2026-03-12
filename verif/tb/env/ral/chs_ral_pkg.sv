// ============================================================================
// chs_ral_pkg.sv — Cheshire SoC Register Abstraction Layer Package
//
// Defines the complete register model for all Cheshire SoC peripherals
// accessible via JTAG → SBA → AXI.
//
// Peripheral    Base Address    Reference
// ─────────────────────────────────────────
// UART 16550    0x0300_2000     OpenTitan compatible
// I2C           0x0300_3000     OpenTitan I2C
// SPI Host      0x0300_4000     OpenTitan SPI Host
// GPIO          0x0300_5000     OpenTitan GPIO
//
// Also includes the SBA adapter that converts RAL front-door
// read/write operations into JTAG → SBA bus transactions.
// ============================================================================

package chs_ral_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import JTAG package for transaction/sequencer types
    import jtag_pkg::*;

    // ──────────────────────────────────────────────────────────────
    //  Include order: registers → blocks → SoC model → adapter
    // ──────────────────────────────────────────────────────────────

    `include "chs_ral_uart_regs.sv"
    `include "chs_ral_spi_regs.sv"
    `include "chs_ral_i2c_regs.sv"
    `include "chs_ral_gpio_regs.sv"
    `include "chs_ral_soc_block.sv"
    `include "chs_ral_adapter.sv"

endpackage : chs_ral_pkg
