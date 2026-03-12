`ifndef I2C_TRANSACTION_SV
`define I2C_TRANSACTION_SV

// ============================================================================
// i2c_transaction.sv — I2C Transaction Item
// Supports read/write operations with address and data payload
// ============================================================================

class i2c_transaction extends uvm_sequence_item;

    // I2C operation type
    typedef enum bit {
        I2C_WRITE = 1'b0,
        I2C_READ  = 1'b1
    } i2c_op_e;

    rand i2c_op_e           op;
    rand bit [6:0]          slave_addr;    // 7-bit slave address
    rand bit [7:0]          data[];        // Data payload (read or write)
    rand bit                nack_on_addr;  // Force NACK on address phase

    // Monitor / status fields
         bit                ack_received;  // ACK received from slave
         bit                start_detected;
         bit                stop_detected;

    constraint c_data_size {
        data.size() inside {[1:64]};
    }

    constraint c_nack_default {
        soft nack_on_addr == 1'b0;
    }

    `uvm_object_utils_begin(i2c_transaction)
        `uvm_field_enum(i2c_op_e, op,             UVM_ALL_ON)
        `uvm_field_int(slave_addr,                 UVM_ALL_ON)
        `uvm_field_array_int(data,                 UVM_ALL_ON)
        `uvm_field_int(nack_on_addr,               UVM_ALL_ON)
        `uvm_field_int(ack_received,               UVM_ALL_ON)
        `uvm_field_int(start_detected,             UVM_ALL_ON)
        `uvm_field_int(stop_detected,              UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "i2c_transaction");
        super.new(name);
    endfunction

endclass : i2c_transaction

`endif // I2C_TRANSACTION_SV
