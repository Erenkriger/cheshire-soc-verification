`ifndef SPI_TRANSACTION_SV
`define SPI_TRANSACTION_SV

// ============================================================================
// spi_transaction.sv — SPI Transaction Item
// Supports Standard, Dual, and Quad SPI modes
// ============================================================================

class spi_transaction extends uvm_sequence_item;

    // SPI transfer mode
    typedef enum bit [1:0] {
        SPI_STANDARD = 2'b00,   // 1-bit MOSI/MISO
        SPI_DUAL     = 2'b01,   // 2-bit bidirectional
        SPI_QUAD     = 2'b10    // 4-bit bidirectional
    } spi_mode_e;

    rand spi_mode_e         mode;
    rand bit [7:0]          data[];        // Payload data (slave response bytes)
    rand bit [1:0]          csb_sel;       // Chip select index
    rand bit                cpol;          // Clock polarity
    rand bit                cpha;          // Clock phase

    // Monitor-captured fields
         bit [3:0]          sd_in_data;    // Raw sd_i sample (per-cycle, monitor use)
         bit [3:0]          sd_out_data;   // Raw sd_o sample (per-cycle, monitor use)
         bit [7:0]          mosi_data[];   // Captured master-out data (monitor)
         bit [7:0]          miso_data[];   // Captured master-in data (monitor)

    constraint c_data_size {
        data.size() inside {[1:256]};
    }

    constraint c_csb_sel {
        csb_sel inside {[0:1]};
    }

    `uvm_object_utils_begin(spi_transaction)
        `uvm_field_enum(spi_mode_e, mode,         UVM_ALL_ON)
        `uvm_field_array_int(data,                 UVM_ALL_ON)
        `uvm_field_int(csb_sel,                    UVM_ALL_ON)
        `uvm_field_int(cpol,                       UVM_ALL_ON)
        `uvm_field_int(cpha,                       UVM_ALL_ON)
        `uvm_field_int(sd_in_data,                 UVM_ALL_ON)
        `uvm_field_int(sd_out_data,                UVM_ALL_ON)
        `uvm_field_array_int(mosi_data,            UVM_ALL_ON)
        `uvm_field_array_int(miso_data,            UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "spi_transaction");
        super.new(name);
    endfunction

endclass : spi_transaction

`endif // SPI_TRANSACTION_SV
