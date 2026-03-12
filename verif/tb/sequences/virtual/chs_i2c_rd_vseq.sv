`ifndef CHS_I2C_RD_VSEQ_SV
`define CHS_I2C_RD_VSEQ_SV

// ============================================================================
// chs_i2c_rd_vseq.sv — I2C Read-back Virtual Sequence
// Write bytes then read them back (write-then-read pattern):
//   1. Write 3 bytes to slave 0x50
//   2. Read back 3 bytes from same address
//   3. Log results for scoreboard analysis
// ============================================================================

class chs_i2c_rd_vseq extends uvm_sequence;

    `uvm_object_utils(chs_i2c_rd_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_i2c_rd_vseq");
        super.new(name);
    endfunction

    virtual task body();
        i2c_base_seq i2c_seq;
        bit [7:0]    rdata;

        `uvm_info(get_type_name(),
                  "===== I2C Read-Back START =====", UVM_LOW)

        i2c_seq = i2c_base_seq::type_id::create("i2c_seq");

        // Step 1: Write known values
        `uvm_info(get_type_name(), "[1/2] Writing 0xAA, 0x55, 0xFF to 0x50", UVM_MEDIUM)
        i2c_seq.write_byte(7'h50, 8'hAA, p_sequencer.m_i2c_sqr);
        i2c_seq.write_byte(7'h50, 8'h55, p_sequencer.m_i2c_sqr);
        i2c_seq.write_byte(7'h50, 8'hFF, p_sequencer.m_i2c_sqr);

        // Step 2: Read back
        `uvm_info(get_type_name(), "[2/2] Reading back 3 bytes from 0x50", UVM_MEDIUM)
        i2c_seq.read_byte(7'h50, rdata, p_sequencer.m_i2c_sqr);
        `uvm_info(get_type_name(), $sformatf("Read[0] = 0x%02h", rdata), UVM_LOW)

        i2c_seq.read_byte(7'h50, rdata, p_sequencer.m_i2c_sqr);
        `uvm_info(get_type_name(), $sformatf("Read[1] = 0x%02h", rdata), UVM_LOW)

        i2c_seq.read_byte(7'h50, rdata, p_sequencer.m_i2c_sqr);
        `uvm_info(get_type_name(), $sformatf("Read[2] = 0x%02h", rdata), UVM_LOW)

        `uvm_info(get_type_name(),
                  "===== I2C Read-Back COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_i2c_rd_vseq

`endif
