// ============================================================================
// vga_transaction.sv — VGA Transaction Item
// Captures VGA timing events and pixel data.
// ============================================================================

`ifndef VGA_TRANSACTION_SV
`define VGA_TRANSACTION_SV

class vga_transaction extends uvm_sequence_item;

    typedef enum { VGA_PIXEL, VGA_HSYNC, VGA_VSYNC, VGA_BLANK } vga_event_e;

    vga_event_e  event_type;
    bit [4:0]    red;
    bit [5:0]    green;
    bit [4:0]    blue;
    bit          hsync;
    bit          vsync;

    // Frame tracking
    int unsigned pixel_x;
    int unsigned pixel_y;
    int unsigned frame_num;
    time         timestamp;

    `uvm_object_utils_begin(vga_transaction)
        `uvm_field_enum(vga_event_e, event_type, UVM_ALL_ON)
        `uvm_field_int(red,       UVM_ALL_ON)
        `uvm_field_int(green,     UVM_ALL_ON)
        `uvm_field_int(blue,      UVM_ALL_ON)
        `uvm_field_int(hsync,     UVM_ALL_ON)
        `uvm_field_int(vsync,     UVM_ALL_ON)
        `uvm_field_int(pixel_x,   UVM_ALL_ON)
        `uvm_field_int(pixel_y,   UVM_ALL_ON)
        `uvm_field_int(frame_num, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "vga_transaction");
        super.new(name);
    endfunction

endclass : vga_transaction

`endif // VGA_TRANSACTION_SV
