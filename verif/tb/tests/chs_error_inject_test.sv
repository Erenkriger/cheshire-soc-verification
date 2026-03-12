// ============================================================================
// chs_error_inject_test.sv — Error Injection Test
//
// Aşama 6: Verifies SoC robustness with deliberate error scenarios.
// Tests invalid address access, RO register writes, NACK tolerance.
// ============================================================================

`ifndef CHS_ERROR_INJECT_TEST_SV
`define CHS_ERROR_INJECT_TEST_SV

// ─── Report Catcher: demote expected SBA errors to UVM_WARNING ───
class sba_error_demote_catcher extends uvm_report_catcher;
    `uvm_object_utils(sba_error_demote_catcher)

    function new(string name = "sba_error_demote_catcher");
        super.new(name);
    endfunction

    function action_e catch();
        // Demote SBA bus errors and DMI BUSY retries (expected in error injection)
        if (get_severity() == UVM_ERROR) begin
            string mid = get_id();
            if (mid == "SBA" || mid == "DMI_RD" || mid == "DMI_WR") begin
                set_severity(UVM_WARNING);
                set_action(UVM_DISPLAY | UVM_LOG);
                return THROW;
            end
        end
        return THROW;
    endfunction
endclass

class chs_error_inject_test extends chs_base_test;

    `uvm_component_utils(chs_error_inject_test)

    sba_error_demote_catcher m_sba_catcher;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 150ms;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "========== Error Injection Test ==========", UVM_LOW)
        `uvm_info(get_type_name(), "Testing: Invalid addr, RO write, NACK, SBA recovery", UVM_LOW)
    endfunction

    virtual task test_body();
        chs_error_inject_vseq vseq;

        // Install catcher to demote SBA errors (they are expected in this test)
        m_sba_catcher = sba_error_demote_catcher::type_id::create("m_sba_catcher");
        uvm_report_cb::add(null, m_sba_catcher);

        vseq = chs_error_inject_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        // Remove catcher after test completes
        uvm_report_cb::delete(null, m_sba_catcher);

        `uvm_info(get_type_name(), "========== Error Injection Test Complete ==========", UVM_LOW)
    endtask

endclass

`endif // CHS_ERROR_INJECT_TEST_SV
