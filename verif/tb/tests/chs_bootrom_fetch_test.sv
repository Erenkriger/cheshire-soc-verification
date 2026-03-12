`ifndef CHS_BOOTROM_FETCH_TEST_SV
`define CHS_BOOTROM_FETCH_TEST_SV

// ============================================================================
// chs_bootrom_fetch_test.sv — Inside-Out Boot Flow Test
// Tests CVA6 BootROM instruction fetch path by loading a program
// into SPM, setting DPC, and resuming core execution.
// ============================================================================

class chs_bootrom_fetch_test extends chs_base_test;

    `uvm_component_utils(chs_bootrom_fetch_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 20ms;  // Longer timeout for core execution
    endfunction

    virtual task test_body();
        chs_bootrom_fetch_vseq vseq;

        `uvm_info(get_type_name(), "===== Inside-Out Boot Flow Test START =====", UVM_LOW)

        vseq = chs_bootrom_fetch_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== Inside-Out Boot Flow Test DONE =====", UVM_LOW)
    endtask

endclass : chs_bootrom_fetch_test

`endif // CHS_BOOTROM_FETCH_TEST_SV
