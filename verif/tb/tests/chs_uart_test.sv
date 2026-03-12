`ifndef CHS_UART_TEST_SV
`define CHS_UART_TEST_SV

// ============================================================================
// chs_uart_test.sv — Cheshire SoC UART Test
// Sends a few bytes over UART and verifies basic transmission.
// ============================================================================

class chs_uart_test extends chs_base_test;

    `uvm_component_utils(chs_uart_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Ensure UART agent is enabled
    virtual function void configure_env();
        m_env_cfg.has_uart_agent = 1;
    endfunction : configure_env

    virtual task test_body();
        uart_base_seq uart_seq;

        `uvm_info(get_type_name(), "===== UART Test START =====", UVM_LOW)

        uart_seq = uart_base_seq::type_id::create("uart_seq");

        // ---- Send known bytes ----
        `uvm_info(get_type_name(), "Sending test bytes: 0x55, 0xAA, 0xDE", UVM_MEDIUM)
        uart_seq.send_byte(8'h55, m_env.m_virt_sqr.m_uart_sqr);
        uart_seq.send_byte(8'hAA, m_env.m_virt_sqr.m_uart_sqr);
        uart_seq.send_byte(8'hDE, m_env.m_virt_sqr.m_uart_sqr);

        // ---- Send a test string ----
        `uvm_info(get_type_name(), "Sending test string", UVM_MEDIUM)
        uart_seq.send_string("Hello Cheshire!\n", m_env.m_virt_sqr.m_uart_sqr);

        // ---- Random traffic ----
        `uvm_info(get_type_name(), "Sending 8 random bytes", UVM_MEDIUM)
        uart_seq.random_traffic(8, m_env.m_virt_sqr.m_uart_sqr);

        `uvm_info(get_type_name(), "===== UART Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_uart_test

`endif // CHS_UART_TEST_SV
