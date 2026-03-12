// ============================================================================
// chs_reg_reset_test.sv — Register Reset Value Verification Test
//
// Aşama 7: Reads all known peripheral registers after reset and
// verifies they contain their documented reset values.
// ============================================================================

`ifndef CHS_REG_RESET_TEST_SV
`define CHS_REG_RESET_TEST_SV

class chs_reg_reset_test extends chs_base_test;

    `uvm_component_utils(chs_reg_reset_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 50ms;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "========== Register Reset Value Test ==========", UVM_LOW)
    endfunction

    virtual task test_body();
        chs_reg_reset_vseq vseq;
        vseq = chs_reg_reset_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);
        `uvm_info(get_type_name(), "========== Register Reset Value Test Complete ==========", UVM_LOW)
    endtask

endclass

`endif // CHS_REG_RESET_TEST_SV
