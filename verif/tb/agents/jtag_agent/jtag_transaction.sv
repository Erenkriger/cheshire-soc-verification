`ifndef JTAG_TRANSACTION_SV
`define JTAG_TRANSACTION_SV

// ============================================================================
// jtag_transaction.sv — JTAG Transaction Item
// Supports IR scan, DR scan, and TAP reset operations
// ============================================================================

class jtag_transaction extends uvm_sequence_item;

    // TAP operation type
    typedef enum bit [1:0] {
        JTAG_RESET   = 2'b00,
        JTAG_IR_SCAN = 2'b01,
        JTAG_DR_SCAN = 2'b10,
        JTAG_IDLE    = 2'b11
    } jtag_op_e;

    rand jtag_op_e          op;
    rand bit [4:0]          ir_value;      // IR length = 5 for RISC-V Debug
    rand bit [63:0]         dr_value;      // DR write data (64-bit for DMI 41-bit support)
    rand int unsigned       dr_length;     // DR scan length in bits
         bit [63:0]         dr_rdata;      // DR read data (captured, 64-bit)
    rand int unsigned       idle_cycles;   // TCK idle cycles after operation

    constraint c_dr_length {
        dr_length inside {[1:64]};
    }

    constraint c_idle_cycles {
        idle_cycles inside {[0:20]};
    }

    `uvm_object_utils_begin(jtag_transaction)
        `uvm_field_enum(jtag_op_e, op,   UVM_ALL_ON)
        `uvm_field_int(ir_value,          UVM_ALL_ON)
        `uvm_field_int(dr_value,          UVM_ALL_ON)
        `uvm_field_int(dr_length,         UVM_ALL_ON)
        `uvm_field_int(dr_rdata,          UVM_ALL_ON)
        `uvm_field_int(idle_cycles,       UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "jtag_transaction");
        super.new(name);
    endfunction

endclass : jtag_transaction

`endif // JTAG_TRANSACTION_SV
