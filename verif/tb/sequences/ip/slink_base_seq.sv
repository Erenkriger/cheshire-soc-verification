`ifndef SLINK_BASE_SEQ_SV
`define SLINK_BASE_SEQ_SV

// ============================================================================
// slink_base_seq.sv — Serial Link Base IP-Level Sequence
// Provides reusable tasks for Serial Link operations.
// ============================================================================

class slink_base_seq extends uvm_sequence #(slink_transaction);

    `uvm_object_utils(slink_base_seq)

    function new(string name = "slink_base_seq");
        super.new(name);
    endfunction

    // Send idle cycles
    virtual task send_idle(int num_cycles, uvm_sequencer_base sqr = null);
        slink_transaction txn;
        txn = slink_transaction::type_id::create("slink_idle");
        start_item(txn, -1, sqr);
        txn.op        = slink_transaction::SLINK_IDLE;
        txn.num_beats = num_cycles;
        finish_item(txn);
    endtask

    // Send a byte payload over the serial link
    virtual task send_data(bit [7:0] data[$], uvm_sequencer_base sqr = null);
        slink_transaction txn;
        txn = slink_transaction::type_id::create("slink_data");
        start_item(txn, -1, sqr);
        txn.op        = slink_transaction::SLINK_TX;
        txn.num_beats = data.size();
        txn.payload   = data;
        finish_item(txn);
    endtask

    // Send a single byte
    virtual task send_byte(bit [7:0] data, uvm_sequencer_base sqr = null);
        bit [7:0] q[$];
        q.push_back(data);
        send_data(q, sqr);
    endtask

    virtual task body();
        `uvm_info(get_type_name(), "slink_base_seq — default body (no-op)", UVM_LOW)
    endtask

endclass : slink_base_seq

`endif // SLINK_BASE_SEQ_SV
