`ifndef CHS_VGA_TEST_SV
`define CHS_VGA_TEST_SV

// ============================================================================
// chs_vga_test.sv — VGA Controller Test
// Tests VGA register configuration and frame buffer writes.
// ============================================================================

class chs_vga_test extends chs_base_test;

    `uvm_component_utils(chs_vga_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 15ms;
    endfunction

    virtual function void configure_env();
        m_env_cfg.has_vga_agent = 1;
        m_env_cfg.m_vga_cfg = vga_config::type_id::create("m_vga_cfg");
    endfunction

    virtual task test_body();
        chs_vga_vseq vseq;

        `uvm_info(get_type_name(), "===== VGA Controller Test START =====", UVM_LOW)

        vseq = chs_vga_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== VGA Controller Test DONE =====", UVM_LOW)
    endtask

endclass : chs_vga_test

`endif // CHS_VGA_TEST_SV
