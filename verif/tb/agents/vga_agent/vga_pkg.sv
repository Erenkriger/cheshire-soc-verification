// ============================================================================
// vga_pkg.sv — VGA Agent Package
// ============================================================================

package vga_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "vga_transaction.sv"
    `include "vga_config.sv"
    `include "vga_monitor.sv"
    `include "vga_agent.sv"

endpackage : vga_pkg
