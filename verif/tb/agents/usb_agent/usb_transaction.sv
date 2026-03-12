// ============================================================================
// usb_transaction.sv — USB 1.1 Transaction Item
// Models USB packet-level transactions for OHCI host controller.
// ============================================================================

`ifndef USB_TRANSACTION_SV
`define USB_TRANSACTION_SV

class usb_transaction extends uvm_sequence_item;

    typedef enum {
        USB_RESET,          // SE0 for >10ms (bus reset)
        USB_SOF,            // Start of Frame
        USB_SETUP,          // SETUP token
        USB_IN,             // IN token
        USB_OUT,            // OUT token
        USB_DATA0,          // DATA0 packet
        USB_DATA1,          // DATA1 packet
        USB_ACK,            // ACK handshake
        USB_NAK,            // NAK handshake
        USB_STALL,          // STALL handshake
        USB_IDLE,           // J state idle
        USB_CONNECT,        // Device connect (D+ pull-up)
        USB_DISCONNECT      // Device disconnect
    } usb_pkt_type_e;

    rand usb_pkt_type_e  pkt_type;
    rand bit [6:0]       dev_addr;
    rand bit [3:0]       endp;
    rand bit [7:0]       payload[$];
    rand int             idle_cycles;

    // Observed
    bit                  dp_state;
    bit                  dm_state;
    time                 timestamp;

    `uvm_object_utils_begin(usb_transaction)
        `uvm_field_enum(usb_pkt_type_e, pkt_type, UVM_ALL_ON)
        `uvm_field_int(dev_addr,     UVM_ALL_ON)
        `uvm_field_int(endp,         UVM_ALL_ON)
        `uvm_field_queue_int(payload, UVM_ALL_ON)
        `uvm_field_int(idle_cycles,  UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_addr   { dev_addr inside {[0:127]}; }
    constraint c_endp   { endp inside {[0:15]}; }
    constraint c_idle   { idle_cycles inside {[1:100]}; }
    constraint c_payload { payload.size() inside {[0:64]}; }

    function new(string name = "usb_transaction");
        super.new(name);
    endfunction

endclass : usb_transaction

`endif // USB_TRANSACTION_SV
