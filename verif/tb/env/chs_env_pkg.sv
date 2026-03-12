// ============================================================================
// chs_env_pkg.sv — Cheshire SoC Environment Package
// ============================================================================

package chs_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import all agent packages
    import jtag_pkg::*;
    import uart_pkg::*;
    import spi_pkg::*;
    import i2c_pkg::*;
    import gpio_pkg::*;
    import chs_axi_pkg::*;
    import slink_pkg::*;
    import vga_pkg::*;
    import usb_pkg::*;

    // Import RAL package
    import chs_ral_pkg::*;

    // Include environment files (order matters: config → helpers → env)
    `include "chs_env_config.sv"
    `include "chs_virtual_sequencer.sv"
    `include "chs_scoreboard.sv"
    `include "chs_coverage.sv"
    `include "chs_env.sv"

endpackage : chs_env_pkg
