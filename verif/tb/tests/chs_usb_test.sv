`ifndef CHS_USB_TEST_SV
`define CHS_USB_TEST_SV

// ============================================================================
// chs_usb_test.sv — USB 1.1 OHCI Test
// Tests USB OHCI register access, device connect, and basic enumeration.
// ============================================================================

class chs_usb_test extends chs_base_test;

    `uvm_component_utils(chs_usb_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 20ms;
    endfunction

    virtual function void configure_env();
        m_env_cfg.has_usb_agent = 1;
        m_env_cfg.m_usb_cfg = usb_config::type_id::create("m_usb_cfg");
    endfunction

    virtual task test_body();
        chs_usb_vseq vseq;

        `uvm_info(get_type_name(), "===== USB 1.1 OHCI Test START =====", UVM_LOW)

        vseq = chs_usb_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== USB 1.1 OHCI Test DONE =====", UVM_LOW)
    endtask

endclass : chs_usb_test

`endif // CHS_USB_TEST_SV
