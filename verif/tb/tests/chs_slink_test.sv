`ifndef CHS_SLINK_TEST_SV
`define CHS_SLINK_TEST_SV

// ============================================================================
// chs_slink_test.sv — Serial Link Test
// Tests Serial Link IP register access and data lane activity.
// ============================================================================

class chs_slink_test extends chs_base_test;

    `uvm_component_utils(chs_slink_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 15ms;
    endfunction

    virtual function void configure_env();
        m_env_cfg.has_slink_agent = 1;
        m_env_cfg.m_slink_cfg = slink_config::type_id::create("m_slink_cfg");
    endfunction

    virtual task test_body();
        chs_slink_vseq vseq;

        `uvm_info(get_type_name(), "===== Serial Link Test START =====", UVM_LOW)

        vseq = chs_slink_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== Serial Link Test DONE =====", UVM_LOW)
    endtask

endclass : chs_slink_test

`endif // CHS_SLINK_TEST_SV
