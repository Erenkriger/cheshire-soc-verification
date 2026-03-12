// ============================================================================
// i2c_pkg.sv — I2C Agent Package
// ============================================================================

package i2c_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "i2c_transaction.sv"
    `include "i2c_config.sv"
    `include "i2c_sequencer.sv"
    `include "i2c_driver.sv"
    `include "i2c_monitor.sv"
    `include "i2c_agent.sv"

endpackage : i2c_pkg
