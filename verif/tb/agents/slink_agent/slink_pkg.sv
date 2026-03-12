// ============================================================================
// slink_pkg.sv — Serial Link Agent Package
// ============================================================================

package slink_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "slink_transaction.sv"
    `include "slink_config.sv"
    `include "slink_sequencer.sv"
    `include "slink_driver.sv"
    `include "slink_monitor.sv"
    `include "slink_agent.sv"

endpackage : slink_pkg
