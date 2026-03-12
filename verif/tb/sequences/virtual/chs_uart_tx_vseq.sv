`ifndef CHS_UART_TX_VSEQ_SV
`define CHS_UART_TX_VSEQ_SV

// ============================================================================
// chs_uart_tx_vseq.sv — UART TX Basic Virtual Sequence
// Sends known byte patterns from TB to DUT RX pin:
//   - Single bytes: 0x55 (alternating), 0xAA, 0xFF, 0x00
//   - A short ASCII string
// Verifies driver can generate proper UART frames.
// ============================================================================

class chs_uart_tx_vseq extends uvm_sequence;

    `uvm_object_utils(chs_uart_tx_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_uart_tx_vseq");
        super.new(name);
    endfunction

    virtual task body();
        uart_base_seq uart_seq;

        `uvm_info(get_type_name(),
                  "===== UART TX Basic START =====", UVM_LOW)

        uart_seq = uart_base_seq::type_id::create("uart_seq");

        // Known pattern bytes
        `uvm_info(get_type_name(), "Sending pattern bytes: 0x55, 0xAA, 0xFF, 0x00", UVM_MEDIUM)
        uart_seq.send_byte(8'h55, p_sequencer.m_uart_sqr);
        uart_seq.send_byte(8'hAA, p_sequencer.m_uart_sqr);
        uart_seq.send_byte(8'hFF, p_sequencer.m_uart_sqr);
        uart_seq.send_byte(8'h00, p_sequencer.m_uart_sqr);

        // ASCII string
        `uvm_info(get_type_name(), "Sending string: SoC_OK", UVM_MEDIUM)
        uart_seq.send_string("SoC_OK\n", p_sequencer.m_uart_sqr);

        `uvm_info(get_type_name(),
                  "===== UART TX Basic COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_uart_tx_vseq

`endif
