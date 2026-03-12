`ifndef CHS_UART_TX_TEST_SV
`define CHS_UART_TX_TEST_SV

// ============================================================================
// chs_uart_tx_test.sv — UART TX Basic Test
// Sends known byte patterns and ASCII string via UART.
// ============================================================================

class chs_uart_tx_test extends chs_base_test;

    `uvm_component_utils(chs_uart_tx_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        chs_uart_tx_vseq vseq;

        `uvm_info(get_type_name(), "===== UART TX Test START =====", UVM_LOW)

        vseq = chs_uart_tx_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== UART TX Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_uart_tx_test

`endif
