// ============================================================================
// chs_ral_access_test.sv — RAL Register Access Test
//
// Aşama 6: Exercises UVM RAL front-door access to all peripherals.
// Enables RAL in environment config and runs chs_ral_access_vseq.
// ============================================================================

`ifndef CHS_RAL_ACCESS_TEST_SV
`define CHS_RAL_ACCESS_TEST_SV

class chs_ral_access_test extends chs_base_test;

    `uvm_component_utils(chs_ral_access_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 100ms;
    endfunction

    virtual function void configure_env();
        m_env_cfg.has_ral = 1;   // Enable RAL model
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "========== RAL Access Test ==========", UVM_LOW)
        `uvm_info(get_type_name(), "Testing: UVM RAL front-door access to all peripherals", UVM_LOW)
    endfunction

    virtual task test_body();
        chs_ral_access_vseq vseq;
        vseq = chs_ral_access_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);
        `uvm_info(get_type_name(), "========== RAL Access Test Complete ==========", UVM_LOW)
    endtask

endclass

`endif // CHS_RAL_ACCESS_TEST_SV
