`ifndef CHS_UART_BURST_VSEQ_SV
`define CHS_UART_BURST_VSEQ_SV

// ============================================================================
// chs_uart_burst_vseq.sv — UART Burst Virtual Sequence
// Sends a burst of randomized UART data to stress the UART RX path.
//   - 16 random bytes
//   - Verifies driver frame generation under back-to-back conditions
// ============================================================================

class chs_uart_burst_vseq extends uvm_sequence;

    `uvm_object_utils(chs_uart_burst_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_uart_burst_vseq");
        super.new(name);
    endfunction

    virtual task body();
        uart_base_seq uart_seq;

        `uvm_info(get_type_name(),
                  "===== UART Burst START =====", UVM_LOW)

        uart_seq = uart_base_seq::type_id::create("uart_seq");

        // Phase 1: Sequential known pattern (walking-1)
        `uvm_info(get_type_name(), "Phase 1: Walking-1 byte pattern", UVM_MEDIUM)
        for (int i = 0; i < 8; i++) begin
            uart_seq.send_byte(8'h01 << i, p_sequencer.m_uart_sqr);
        end

        // Phase 2: Random burst
        `uvm_info(get_type_name(), "Phase 2: 16-byte random burst", UVM_MEDIUM)
        uart_seq.random_traffic(16, p_sequencer.m_uart_sqr);

        // Phase 3: Max/min values
        `uvm_info(get_type_name(), "Phase 3: Boundary values", UVM_MEDIUM)
        uart_seq.send_byte(8'h00, p_sequencer.m_uart_sqr);
        uart_seq.send_byte(8'hFF, p_sequencer.m_uart_sqr);
        uart_seq.send_byte(8'h7F, p_sequencer.m_uart_sqr);
        uart_seq.send_byte(8'h80, p_sequencer.m_uart_sqr);

        `uvm_info(get_type_name(),
                  "===== UART Burst COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_uart_burst_vseq

`endif
