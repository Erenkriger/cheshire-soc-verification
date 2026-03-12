// ============================================================================
// chs_cov_uart_boundary_test.sv — UART Boundary Coverage Test
// ============================================================================

`ifndef CHS_COV_UART_BOUNDARY_TEST_SV
`define CHS_COV_UART_BOUNDARY_TEST_SV

class chs_cov_uart_boundary_test extends chs_base_test;

    `uvm_component_utils(chs_cov_uart_boundary_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 200ms;
    endfunction

    virtual task test_body();
        chs_cov_uart_boundary_vseq vseq;

        `uvm_info(get_type_name(),
            "========== UART Boundary Coverage Test ==========", UVM_LOW)
        `uvm_info(get_type_name(),
            "Targets: All 8 data bins, DEL, control chars, high range", UVM_LOW)

        vseq = chs_cov_uart_boundary_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
            "========== UART Boundary Coverage Complete ==========", UVM_LOW)
    endtask : test_body

endclass : chs_cov_uart_boundary_test

`endif // CHS_COV_UART_BOUNDARY_TEST_SV
