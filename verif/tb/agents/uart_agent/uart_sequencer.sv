`ifndef UART_SEQUENCER_SV
`define UART_SEQUENCER_SV

// ============================================================================
// uart_sequencer.sv — UART Sequencer
// ============================================================================

class uart_sequencer extends uvm_sequencer #(uart_transaction);

    `uvm_component_utils(uart_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : uart_sequencer

`endif // UART_SEQUENCER_SV
