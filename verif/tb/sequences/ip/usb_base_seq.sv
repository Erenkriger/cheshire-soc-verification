`ifndef USB_BASE_SEQ_SV
`define USB_BASE_SEQ_SV

// ============================================================================
// usb_base_seq.sv — USB 1.1 Base IP-Level Sequence
// Provides reusable tasks for USB operations.
// ============================================================================

class usb_base_seq extends uvm_sequence #(usb_transaction);

    `uvm_object_utils(usb_base_seq)

    function new(string name = "usb_base_seq");
        super.new(name);
    endfunction

    // Device connect (pull-up D+ to signal full-speed device)
    virtual task device_connect(uvm_sequencer_base sqr = null);
        usb_transaction txn;
        txn = usb_transaction::type_id::create("usb_connect");
        start_item(txn, -1, sqr);
        txn.pkt_type = usb_transaction::USB_CONNECT;
        finish_item(txn);
        `uvm_info(get_type_name(), "USB device connected", UVM_MEDIUM)
    endtask

    // Device disconnect
    virtual task device_disconnect(uvm_sequencer_base sqr = null);
        usb_transaction txn;
        txn = usb_transaction::type_id::create("usb_disconnect");
        start_item(txn, -1, sqr);
        txn.pkt_type = usb_transaction::USB_DISCONNECT;
        finish_item(txn);
        `uvm_info(get_type_name(), "USB device disconnected", UVM_MEDIUM)
    endtask

    // Send bus reset
    virtual task bus_reset(uvm_sequencer_base sqr = null);
        usb_transaction txn;
        txn = usb_transaction::type_id::create("usb_reset");
        start_item(txn, -1, sqr);
        txn.pkt_type = usb_transaction::USB_RESET;
        finish_item(txn);
        `uvm_info(get_type_name(), "USB bus reset sent", UVM_MEDIUM)
    endtask

    // Send ACK handshake
    virtual task send_ack(uvm_sequencer_base sqr = null);
        usb_transaction txn;
        txn = usb_transaction::type_id::create("usb_ack");
        start_item(txn, -1, sqr);
        txn.pkt_type = usb_transaction::USB_ACK;
        finish_item(txn);
    endtask

    // Send NAK handshake
    virtual task send_nak(uvm_sequencer_base sqr = null);
        usb_transaction txn;
        txn = usb_transaction::type_id::create("usb_nak");
        start_item(txn, -1, sqr);
        txn.pkt_type = usb_transaction::USB_NAK;
        finish_item(txn);
    endtask

    // Send DATA0 packet
    virtual task send_data0(bit [7:0] payload[$], uvm_sequencer_base sqr = null);
        usb_transaction txn;
        txn = usb_transaction::type_id::create("usb_data0");
        start_item(txn, -1, sqr);
        txn.pkt_type = usb_transaction::USB_DATA0;
        txn.payload  = payload;
        finish_item(txn);
    endtask

    // Send idle
    virtual task send_idle(int cycles, uvm_sequencer_base sqr = null);
        usb_transaction txn;
        txn = usb_transaction::type_id::create("usb_idle");
        start_item(txn, -1, sqr);
        txn.pkt_type    = usb_transaction::USB_IDLE;
        txn.idle_cycles = cycles;
        finish_item(txn);
    endtask

    virtual task body();
        `uvm_info(get_type_name(), "usb_base_seq — default body (no-op)", UVM_LOW)
    endtask

endclass : usb_base_seq

`endif // USB_BASE_SEQ_SV
