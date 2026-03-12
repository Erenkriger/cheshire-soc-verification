`ifndef GPIO_TRANSACTION_SV
`define GPIO_TRANSACTION_SV

// ============================================================================
// gpio_transaction.sv — GPIO Transaction Item
// Supports driving inputs to DUT and reading DUT outputs
// ============================================================================

class gpio_transaction extends uvm_sequence_item;

    // GPIO operation type
    typedef enum bit {
        DRIVE_INPUT  = 1'b0,   // TB drives gpio_i (stimulus into DUT)
        READ_OUTPUT  = 1'b1    // Monitor captures gpio_o / gpio_en_o
    } gpio_op_e;

    rand gpio_op_e      op;
    rand bit [31:0]     data;              // Drive data (for DRIVE_INPUT) or captured gpio_o
    rand bit [31:0]     mask;              // Bit mask: which pins to affect
         bit [31:0]     observed_output;   // Captured gpio_o value (monitor)
         bit [31:0]     observed_en;       // Captured gpio_en_o value (monitor)

    `uvm_object_utils_begin(gpio_transaction)
        `uvm_field_enum(gpio_op_e, op,          UVM_ALL_ON)
        `uvm_field_int(data,                    UVM_ALL_ON)
        `uvm_field_int(mask,                    UVM_ALL_ON)
        `uvm_field_int(observed_output,         UVM_ALL_ON)
        `uvm_field_int(observed_en,             UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "gpio_transaction");
        super.new(name);
    endfunction

endclass : gpio_transaction

`endif // GPIO_TRANSACTION_SV
