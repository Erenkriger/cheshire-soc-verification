`ifndef UART_BASE_SEQ_SV
`define UART_BASE_SEQ_SV

// ============================================================================
// uart_base_seq.sv — Base UART Sequence
// Provides reusable helper tasks:
//   - send_byte, send_string, random_traffic
// ============================================================================

class uart_base_seq extends uvm_sequence #(uart_transaction);

    `uvm_object_utils(uart_base_seq)

    function new(string name = "uart_base_seq");
        super.new(name);
    endfunction

    // ========================== Helper Tasks ==========================

    // ---- Send Single Byte ----
    virtual task send_byte(bit [7:0] data, uvm_sequencer_base sqr = null);
        uart_transaction txn;
        txn = uart_transaction::type_id::create("txn_byte");
        start_item(txn, -1, sqr);
        txn.direction     = uart_transaction::UART_TX;
        txn.data          = data;
        txn.parity_en     = 0;
        txn.num_stop_bits = 1;
        finish_item(txn);
        `uvm_info(get_type_name(), $sformatf("UART TX byte: 0x%02h ('%c')", data, data),
                  UVM_HIGH)
    endtask : send_byte

    // ---- Send String ----
    virtual task send_string(string s, uvm_sequencer_base sqr = null);
        `uvm_info(get_type_name(),
                  $sformatf("UART TX string: \"%s\" (%0d chars)", s, s.len()), UVM_MEDIUM)
        for (int i = 0; i < s.len(); i++) begin
            send_byte(s.getc(i), sqr);
        end
    endtask : send_string

    // ---- Random Traffic ----
    virtual task random_traffic(int count, uvm_sequencer_base sqr = null);
        uart_transaction txn;
        `uvm_info(get_type_name(),
                  $sformatf("UART random traffic: %0d bytes", count), UVM_MEDIUM)
        for (int i = 0; i < count; i++) begin
            txn = uart_transaction::type_id::create($sformatf("txn_rand_%0d", i));
            start_item(txn, -1, sqr);
            if (!txn.randomize() with { direction == uart_transaction::UART_TX; })
                `uvm_error(get_type_name(), "Randomization failed")
            finish_item(txn);
        end
    endtask : random_traffic

    // ========================== Default body ==========================
    virtual task body();
        `uvm_info(get_type_name(), "uart_base_seq — default body (no-op)", UVM_LOW)
    endtask : body

endclass : uart_base_seq

`endif // UART_BASE_SEQ_SV
