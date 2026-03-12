`ifndef CHS_UART_BURST_TEST_SV
`define CHS_UART_BURST_TEST_SV

// ============================================================================
// chs_uart_burst_test.sv — UART Burst Test
// Sends walking-1 pattern + random burst + boundary values.
// ============================================================================

class chs_uart_burst_test extends chs_base_test;

    `uvm_component_utils(chs_uart_burst_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        chs_uart_burst_vseq vseq;

        `uvm_info(get_type_name(), "===== UART Burst Test START =====", UVM_LOW)

        vseq = chs_uart_burst_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== UART Burst Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_uart_burst_test

`endif
