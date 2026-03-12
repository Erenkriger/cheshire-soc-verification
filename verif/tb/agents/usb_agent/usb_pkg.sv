// ============================================================================
// usb_pkg.sv — USB Agent Package
// ============================================================================

package usb_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "usb_transaction.sv"
    `include "usb_config.sv"
    `include "usb_sequencer.sv"
    `include "usb_driver.sv"
    `include "usb_monitor.sv"
    `include "usb_agent.sv"

endpackage : usb_pkg
