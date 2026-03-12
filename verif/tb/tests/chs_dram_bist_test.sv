`ifndef CHS_DRAM_BIST_TEST_SV
`define CHS_DRAM_BIST_TEST_SV

// ============================================================================
// chs_dram_bist_test.sv — DRAM Controller Active BIST Test
// Performs memory BIST patterns via SBA on the DRAM region.
// ============================================================================

class chs_dram_bist_test extends chs_base_test;

    `uvm_component_utils(chs_dram_bist_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 30ms;
    endfunction

    virtual task test_body();
        chs_dram_bist_vseq vseq;

        `uvm_info(get_type_name(), "===== DRAM Active BIST Test START =====", UVM_LOW)

        vseq = chs_dram_bist_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== DRAM Active BIST Test DONE =====", UVM_LOW)
    endtask

endclass : chs_dram_bist_test

`endif // CHS_DRAM_BIST_TEST_SV
