// ============================================================================
// chs_boot_seq_test.sv — Boot Sequence Verification Test
//
// Aşama 7: Verifies JTAG boot flow: TAP reset, DM activation,
// core halt/resume, SBCS capabilities, boot ROM presence.
// ============================================================================

`ifndef CHS_BOOT_SEQ_TEST_SV
`define CHS_BOOT_SEQ_TEST_SV

class chs_boot_seq_test extends chs_base_test;

    `uvm_component_utils(chs_boot_seq_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 50ms;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "========== Boot Sequence Test ==========", UVM_LOW)
    endfunction

    virtual task test_body();
        chs_boot_seq_vseq vseq;
        vseq = chs_boot_seq_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);
        `uvm_info(get_type_name(), "========== Boot Sequence Test Complete ==========", UVM_LOW)
    endtask

endclass

`endif // CHS_BOOT_SEQ_TEST_SV
