`ifndef SPI_SEQUENCER_SV
`define SPI_SEQUENCER_SV

// ============================================================================
// spi_sequencer.sv — SPI Sequencer
// ============================================================================

class spi_sequencer extends uvm_sequencer #(spi_transaction);

    `uvm_component_utils(spi_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : spi_sequencer

`endif // SPI_SEQUENCER_SV
