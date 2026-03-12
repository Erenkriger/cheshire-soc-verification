`ifndef CHS_SANITY_TEST_SV
`define CHS_SANITY_TEST_SV

// ============================================================================
// chs_sanity_test.sv — Cheshire SoC Sanity Test
// Runs the smoke virtual sequence to verify basic connectivity
// across JTAG and GPIO interfaces.
// ============================================================================

class chs_sanity_test extends chs_base_test;

    `uvm_component_utils(chs_sanity_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        chs_smoke_vseq vseq;

        `uvm_info(get_type_name(), "===== Sanity Test START =====", UVM_LOW)

        vseq = chs_smoke_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== Sanity Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_sanity_test

`endif // CHS_SANITY_TEST_SV
