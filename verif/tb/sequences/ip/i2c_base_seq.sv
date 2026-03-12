`ifndef I2C_BASE_SEQ_SV
`define I2C_BASE_SEQ_SV

// ============================================================================
// i2c_base_seq.sv — Base I2C Sequence
// Provides reusable helper tasks:
//   - write_byte, read_byte, write_block
// ============================================================================

class i2c_base_seq extends uvm_sequence #(i2c_transaction);

    `uvm_object_utils(i2c_base_seq)

    function new(string name = "i2c_base_seq");
        super.new(name);
    endfunction

    // ========================== Helper Tasks ==========================

    // ---- Write Single Byte ----
    virtual task write_byte(bit [6:0] addr, bit [7:0] data,
                            uvm_sequencer_base sqr = null);
        i2c_transaction txn;
        txn = i2c_transaction::type_id::create("txn_wr");
        start_item(txn, -1, sqr);
        txn.op         = i2c_transaction::I2C_WRITE;
        txn.slave_addr = addr;
        txn.data       = new[1];
        txn.data[0]    = data;
        finish_item(txn);
        `uvm_info(get_type_name(),
                  $sformatf("I2C write: addr=0x%02h data=0x%02h ack=%0b",
                            addr, data, txn.ack_received), UVM_HIGH)
    endtask : write_byte

    // ---- Read Single Byte ----
    virtual task read_byte(bit [6:0] addr, output bit [7:0] data,
                           input uvm_sequencer_base sqr = null);
        i2c_transaction txn;
        txn = i2c_transaction::type_id::create("txn_rd");
        start_item(txn, -1, sqr);
        txn.op         = i2c_transaction::I2C_READ;
        txn.slave_addr = addr;
        txn.data       = new[1];
        txn.data[0]    = 8'h00;
        finish_item(txn);
        data = txn.data[0];
        `uvm_info(get_type_name(),
                  $sformatf("I2C read: addr=0x%02h data=0x%02h ack=%0b",
                            addr, data, txn.ack_received), UVM_HIGH)
    endtask : read_byte

    // ---- Write Block (Multi-byte) ----
    virtual task write_block(bit [6:0] addr, bit [7:0] data[], int len,
                             uvm_sequencer_base sqr = null);
        i2c_transaction txn;
        txn = i2c_transaction::type_id::create("txn_wr_blk");
        start_item(txn, -1, sqr);
        txn.op         = i2c_transaction::I2C_WRITE;
        txn.slave_addr = addr;
        txn.data       = new[len];
        for (int i = 0; i < len; i++)
            txn.data[i] = data[i];
        finish_item(txn);
        `uvm_info(get_type_name(),
                  $sformatf("I2C block write: addr=0x%02h len=%0d", addr, len), UVM_MEDIUM)
    endtask : write_block

    // ========================== Default body ==========================
    virtual task body();
        `uvm_info(get_type_name(), "i2c_base_seq — default body (no-op)", UVM_LOW)
    endtask : body

endclass : i2c_base_seq

`endif // I2C_BASE_SEQ_SV
