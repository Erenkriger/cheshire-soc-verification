`ifndef CHS_JTAG_DMI_TEST_SV
`define CHS_JTAG_DMI_TEST_SV

// ============================================================================
// chs_jtag_dmi_test.sv — JTAG DMI Access Test
// Accesses RISC-V Debug Module via DMI: dmcontrol write, dmstatus read.
// ============================================================================

class chs_jtag_dmi_test extends chs_base_test;

    `uvm_component_utils(chs_jtag_dmi_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        chs_jtag_dmi_vseq vseq;

        `uvm_info(get_type_name(), "===== JTAG DMI Test START =====", UVM_LOW)

        vseq = chs_jtag_dmi_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== JTAG DMI Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_jtag_dmi_test

`endif
