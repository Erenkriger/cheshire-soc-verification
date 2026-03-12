`ifndef CHS_IDMA_TEST_SV
`define CHS_IDMA_TEST_SV

// ============================================================================
// chs_idma_test.sv — iDMA Engine Test
// Tests iDMA register access and memory-to-memory transfer.
// ============================================================================

class chs_idma_test extends chs_base_test;

    `uvm_component_utils(chs_idma_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 15ms;
    endfunction

    virtual task test_body();
        chs_idma_vseq vseq;

        `uvm_info(get_type_name(), "===== iDMA Engine Test START =====", UVM_LOW)

        vseq = chs_idma_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== iDMA Engine Test DONE =====", UVM_LOW)
    endtask

endclass : chs_idma_test

`endif // CHS_IDMA_TEST_SV
