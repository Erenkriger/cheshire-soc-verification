// ============================================================================
// spi_pkg.sv — SPI Agent Package
// ============================================================================

package spi_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "spi_transaction.sv"
    `include "spi_config.sv"
    `include "spi_sequencer.sv"
    `include "spi_driver.sv"
    `include "spi_monitor.sv"
    `include "spi_agent.sv"

endpackage : spi_pkg
