// ============================================================================
// chs_cov_axi_region_test.sv — AXI Region Coverage Test
//
// Uses sba_error_demote_catcher to handle expected DECERR from unmapped
// region accesses.
// ============================================================================

`ifndef CHS_COV_AXI_REGION_TEST_SV
`define CHS_COV_AXI_REGION_TEST_SV

class chs_cov_axi_region_test extends chs_base_test;

    `uvm_component_utils(chs_cov_axi_region_test)

    // Error demote catcher (reuse pattern from chs_error_inject_test)
    class sba_error_demote_catcher extends uvm_report_catcher;
        `uvm_object_utils(sba_error_demote_catcher)

        function new(string name = "sba_error_demote_catcher");
            super.new(name);
        endfunction

        function action_e catch();
            if (get_severity() == UVM_ERROR) begin
                string msg_id = get_id();
                if (msg_id == "SBA" || msg_id == "DMI_WR" || msg_id == "DMI_RD" ||
                    msg_id == "SBA_ERROR" || msg_id == "SBA_READ") begin
                    set_severity(UVM_WARNING);
                    return THROW;
                end
            end
            return THROW;
        endfunction
    endclass

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 200ms;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        sba_error_demote_catcher catcher;
        super.build_phase(phase);
        // Register catcher to demote SBA errors from unmapped access
        catcher = sba_error_demote_catcher::type_id::create("catcher");
        uvm_report_cb::add(null, catcher);
    endfunction

    virtual task test_body();
        chs_cov_axi_region_vseq vseq;

        `uvm_info(get_type_name(),
            "========== AXI Region Coverage Test ==========", UVM_LOW)
        `uvm_info(get_type_name(),
            "Targets: All 8 AXI regions (DEBUG→UNMAPPED), R/W cross", UVM_LOW)

        vseq = chs_cov_axi_region_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
            "========== AXI Region Coverage Complete ==========", UVM_LOW)
    endtask : test_body

endclass : chs_cov_axi_region_test

`endif // CHS_COV_AXI_REGION_TEST_SV
