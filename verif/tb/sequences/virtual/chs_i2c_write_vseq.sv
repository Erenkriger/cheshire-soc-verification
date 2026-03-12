`ifndef CHS_I2C_WRITE_VSEQ_SV
`define CHS_I2C_WRITE_VSEQ_SV

// ============================================================================
// chs_i2c_write_vseq.sv — I2C Write Virtual Sequence
// Sends I2C write transactions to a slave address:
//   1. Single byte write
//   2. Multi-byte block write
// ============================================================================

class chs_i2c_write_vseq extends uvm_sequence;

    `uvm_object_utils(chs_i2c_write_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_i2c_write_vseq");
        super.new(name);
    endfunction

    virtual task body();
        i2c_base_seq i2c_seq;
        bit [7:0]    block_data[];

        `uvm_info(get_type_name(),
                  "===== I2C Write START =====", UVM_LOW)

        i2c_seq = i2c_base_seq::type_id::create("i2c_seq");

        // Step 1: Single byte writes to address 0x50 (typical EEPROM)
        `uvm_info(get_type_name(), "[1/2] Single byte writes to 0x50", UVM_MEDIUM)
        i2c_seq.write_byte(7'h50, 8'hDE, p_sequencer.m_i2c_sqr);
        i2c_seq.write_byte(7'h50, 8'hAD, p_sequencer.m_i2c_sqr);
        i2c_seq.write_byte(7'h50, 8'hBE, p_sequencer.m_i2c_sqr);
        i2c_seq.write_byte(7'h50, 8'hEF, p_sequencer.m_i2c_sqr);

        // Step 2: Block write (4 bytes)
        `uvm_info(get_type_name(), "[2/2] Block write to 0x50 (4 bytes)", UVM_MEDIUM)
        block_data = new[4];
        block_data[0] = 8'h01;
        block_data[1] = 8'h02;
        block_data[2] = 8'h03;
        block_data[3] = 8'h04;
        i2c_seq.write_block(7'h50, block_data, 4, p_sequencer.m_i2c_sqr);

        `uvm_info(get_type_name(),
                  "===== I2C Write COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_i2c_write_vseq

`endif
