`ifndef CHS_JTAG_IDCODE_TEST_SV
`define CHS_JTAG_IDCODE_TEST_SV

// ============================================================================
// chs_jtag_idcode_test.sv — JTAG IDCODE Verification Test
// Reads IDCODE twice and verifies LSB=1 and consistency.
// ============================================================================

class chs_jtag_idcode_test extends chs_base_test;

    `uvm_component_utils(chs_jtag_idcode_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        chs_jtag_idcode_vseq vseq;

        `uvm_info(get_type_name(), "===== JTAG IDCODE Test START =====", UVM_LOW)

        vseq = chs_jtag_idcode_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== JTAG IDCODE Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_jtag_idcode_test

`endif
