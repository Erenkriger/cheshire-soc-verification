// ============================================================================
// chs_cov_allproto_test.sv — All-Protocol Cross Coverage Test
// ============================================================================

`ifndef CHS_COV_ALLPROTO_TEST_SV
`define CHS_COV_ALLPROTO_TEST_SV

class chs_cov_allproto_test extends chs_base_test;

    `uvm_component_utils(chs_cov_allproto_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 200ms;
    endfunction

    virtual task test_body();
        chs_cov_allproto_vseq vseq;

        `uvm_info(get_type_name(),
            "========== All-Protocol Cross Coverage Test ==========", UVM_LOW)
        `uvm_info(get_type_name(),
            "Targets: Cross-protocol all_active bin, SPI+I2C+UART+GPIO", UVM_LOW)

        vseq = chs_cov_allproto_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
            "========== All-Protocol Cross Coverage Complete ==========", UVM_LOW)
    endtask : test_body

endclass : chs_cov_allproto_test

`endif // CHS_COV_ALLPROTO_TEST_SV
