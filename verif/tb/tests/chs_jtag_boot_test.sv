`ifndef CHS_JTAG_BOOT_TEST_SV
`define CHS_JTAG_BOOT_TEST_SV

// ============================================================================
// chs_jtag_boot_test.sv — Cheshire SoC JTAG Boot Test
// Exercises the JTAG boot virtual sequence: TAP reset, IDCODE,
// DMI access, halt request, and status readback.
// ============================================================================

class chs_jtag_boot_test extends chs_base_test;

    `uvm_component_utils(chs_jtag_boot_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Ensure JTAG agent is enabled and boot mode is JTAG
    virtual function void configure_env();
        m_env_cfg.has_jtag_agent = 1;
        m_env_cfg.boot_mode      = 2'b00;  // JTAG boot
    endfunction : configure_env

    virtual task test_body();
        chs_boot_jtag_vseq vseq;

        `uvm_info(get_type_name(), "===== JTAG Boot Test START =====", UVM_LOW)

        vseq = chs_boot_jtag_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== JTAG Boot Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_jtag_boot_test

`endif // CHS_JTAG_BOOT_TEST_SV
