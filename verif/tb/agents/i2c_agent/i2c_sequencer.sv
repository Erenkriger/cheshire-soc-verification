`ifndef I2C_SEQUENCER_SV
`define I2C_SEQUENCER_SV

// ============================================================================
// i2c_sequencer.sv — I2C Sequencer
// ============================================================================

class i2c_sequencer extends uvm_sequencer #(i2c_transaction);

    `uvm_component_utils(i2c_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : i2c_sequencer

`endif // I2C_SEQUENCER_SV
