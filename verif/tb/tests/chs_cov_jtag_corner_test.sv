// ============================================================================
// chs_cov_jtag_corner_test.sv — JTAG Corner-Case Coverage Test
// ============================================================================

`ifndef CHS_COV_JTAG_CORNER_TEST_SV
`define CHS_COV_JTAG_CORNER_TEST_SV

class chs_cov_jtag_corner_test extends chs_base_test;

    `uvm_component_utils(chs_cov_jtag_corner_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 50ms;
    endfunction

    virtual task test_body();
        chs_cov_jtag_corner_vseq vseq;

        `uvm_info(get_type_name(),
            "========== JTAG Corner-Case Coverage Test ==========", UVM_LOW)
        `uvm_info(get_type_name(),
            "Targets: All IR bins, DR length sweep, DMI ops, DMI addrs", UVM_LOW)

        vseq = chs_cov_jtag_corner_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
            "========== JTAG Corner-Case Coverage Complete ==========", UVM_LOW)
    endtask : test_body

endclass : chs_cov_jtag_corner_test

`endif // CHS_COV_JTAG_CORNER_TEST_SV
