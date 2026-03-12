`ifndef JTAG_SEQUENCER_SV
`define JTAG_SEQUENCER_SV

// ============================================================================
// jtag_sequencer.sv — JTAG Sequencer
// ============================================================================

class jtag_sequencer extends uvm_sequencer #(jtag_transaction);

    `uvm_component_utils(jtag_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : jtag_sequencer

`endif // JTAG_SEQUENCER_SV
