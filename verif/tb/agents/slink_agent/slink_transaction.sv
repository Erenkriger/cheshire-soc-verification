// ============================================================================
// slink_transaction.sv — Serial Link Transaction Item
// ============================================================================

`ifndef SLINK_TRANSACTION_SV
`define SLINK_TRANSACTION_SV

class slink_transaction extends uvm_sequence_item;

    // Transaction type
    typedef enum { SLINK_TX, SLINK_RX, SLINK_IDLE } slink_op_e;

    rand slink_op_e  op;
    rand bit [3:0]   lane_data;      // Per-cycle lane data (4 lanes)
    rand int         num_beats;      // Number of data beats
    rand bit [7:0]   payload[$];     // Byte payload for multi-beat transfers
    int              channel;        // Channel index

    // Timing
    time             timestamp;

    `uvm_object_utils_begin(slink_transaction)
        `uvm_field_enum(slink_op_e, op,    UVM_ALL_ON)
        `uvm_field_int(lane_data,          UVM_ALL_ON)
        `uvm_field_int(num_beats,          UVM_ALL_ON)
        `uvm_field_int(channel,            UVM_ALL_ON)
        `uvm_field_queue_int(payload,      UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_beats { num_beats inside {[1:256]}; }
    constraint c_payload_size { payload.size() == num_beats; }

    function new(string name = "slink_transaction");
        super.new(name);
    endfunction

endclass : slink_transaction

`endif // SLINK_TRANSACTION_SV
