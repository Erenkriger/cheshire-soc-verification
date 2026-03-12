// ============================================================================
// chs_axi_pkg.sv — AXI Agent Package for Cheshire SoC
//
// Contains: sequence item, monitor, agent for AXI LLC/DRAM port monitoring.
// ============================================================================

package chs_axi_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "chs_axi_seq_item.sv"
    `include "chs_axi_monitor.sv"
    `include "chs_axi_agent.sv"

endpackage : chs_axi_pkg
