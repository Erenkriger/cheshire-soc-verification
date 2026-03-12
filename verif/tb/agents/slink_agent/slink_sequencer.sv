// ============================================================================
// slink_sequencer.sv — Serial Link Sequencer
// ============================================================================

`ifndef SLINK_SEQUENCER_SV
`define SLINK_SEQUENCER_SV

class slink_sequencer extends uvm_sequencer #(slink_transaction);

    `uvm_component_utils(slink_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : slink_sequencer

`endif // SLINK_SEQUENCER_SV
