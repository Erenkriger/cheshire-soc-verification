`ifndef UART_TRANSACTION_SV
`define UART_TRANSACTION_SV

// ============================================================================
// uart_transaction.sv — UART Transaction Item
// ============================================================================

class uart_transaction extends uvm_sequence_item;

    typedef enum bit { UART_TX = 1'b0, UART_RX = 1'b1 } uart_dir_e;

    rand uart_dir_e    direction;
    rand bit [7:0]     data;
    rand bit           parity_en;
    rand bit           parity_even;  // 0=odd, 1=even
    rand int unsigned  num_stop_bits; // 1 or 2
         bit           frame_error;
         bit           parity_error;

    constraint c_stop_bits { num_stop_bits inside {1, 2}; }

    `uvm_object_utils_begin(uart_transaction)
        `uvm_field_enum(uart_dir_e, direction, UVM_ALL_ON)
        `uvm_field_int(data,           UVM_ALL_ON)
        `uvm_field_int(parity_en,      UVM_ALL_ON)
        `uvm_field_int(parity_even,    UVM_ALL_ON)
        `uvm_field_int(num_stop_bits,  UVM_ALL_ON)
        `uvm_field_int(frame_error,    UVM_ALL_ON)
        `uvm_field_int(parity_error,   UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "uart_transaction");
        super.new(name);
    endfunction

endclass : uart_transaction

`endif // UART_TRANSACTION_SV
