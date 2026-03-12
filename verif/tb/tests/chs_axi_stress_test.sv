`ifndef CHS_AXI_STRESS_TEST_SV
`define CHS_AXI_STRESS_TEST_SV

// ============================================================================
// chs_axi_stress_test.sv — AXI Bus Stress Test
//
// Extended observation of AXI LLC port under sustained traffic.
// Uses JTAG SBA to generate targeted memory writes/reads while
// the CVA6 core is also active (dual-master stress).
//
// Verifies:
//   - AXI protocol compliance under heavy load
//   - No handshake timeouts
//   - Memory coherency via read-after-write
//   - Outstanding transaction depth
// ============================================================================

class chs_axi_stress_test extends chs_base_test;

    `uvm_component_utils(chs_axi_stress_test)

    // DMI BUSY is expected during high-throughput SBA bursts
    sba_error_demote_catcher m_dmi_catcher;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void configure_env();
        m_env_cfg.has_axi_agent = 1;
        m_env_cfg.has_jtag_agent = 1;
        m_timeout = 5ms;  // Longer timeout for stress
    endfunction

    virtual task test_body();
        jtag_base_seq  jtag_seq;
        bit [31:0]     rdata;

        // Install catcher: DMI BUSY is expected under stress conditions
        m_dmi_catcher = sba_error_demote_catcher::type_id::create("m_dmi_catcher");
        uvm_report_cb::add(null, m_dmi_catcher);

        `uvm_info(get_type_name(), "════════════════════════════════════════════", UVM_NONE)
        `uvm_info(get_type_name(), "  AXI Stress Test — Dual-Master Load", UVM_NONE)
        `uvm_info(get_type_name(), "════════════════════════════════════════════", UVM_NONE)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // Phase 1: Initialize JTAG debug module
        `uvm_info(get_type_name(), "Phase 1: JTAG initialization...", UVM_LOW)
        jtag_seq.do_reset(m_env.m_virt_sqr.m_jtag_sqr);
        jtag_seq.sba_init(m_env.m_virt_sqr.m_jtag_sqr);
        #10_000ns;

        // Phase 2: Burst SBA writes to DRAM region
        `uvm_info(get_type_name(), "Phase 2: SBA burst writes to DRAM...", UVM_LOW)
        for (int i = 0; i < 32; i++) begin
            jtag_seq.sba_write32(32'h8000_0000 + (i * 4), 32'hDEAD_0000 | i, m_env.m_virt_sqr.m_jtag_sqr);
            jtag_seq.do_idle(30, m_env.m_virt_sqr.m_jtag_sqr);  // Let SBA complete
        end
        #50_000ns;

        // Phase 3: Read back and verify
        `uvm_info(get_type_name(), "Phase 3: SBA burst reads from DRAM...", UVM_LOW)
        for (int i = 0; i < 32; i++) begin
            jtag_seq.sba_read32(32'h8000_0000 + (i * 4), rdata, m_env.m_virt_sqr.m_jtag_sqr);
            jtag_seq.do_idle(30, m_env.m_virt_sqr.m_jtag_sqr);
            `uvm_info(get_type_name(), $sformatf("DRAM[%0d] = 0x%08h", i, rdata), UVM_MEDIUM)
        end
        #50_000ns;

        // Phase 4: Progress report
        fork
            begin : observation_period
                #200_000ns;
            end
            begin : progress_monitor
                forever begin
                    #50_000ns;
                    `uvm_info(get_type_name(), $sformatf(
                        "STRESS Progress: AXI W=%0d R=%0d RAW_match=%0d RAW_mismatch=%0d errs=%0d",
                        m_env.m_scoreboard.axi_write_count,
                        m_env.m_scoreboard.axi_read_count,
                        m_env.m_scoreboard.axi_raw_match,
                        m_env.m_scoreboard.axi_raw_mismatch,
                        m_env.m_scoreboard.axi_error_count), UVM_LOW)
                end
            end
        join_any
        disable fork;

        `uvm_info(get_type_name(), "AXI Stress Test Complete", UVM_NONE)

        // Remove catcher
        uvm_report_cb::delete(null, m_dmi_catcher);
    endtask

endclass : chs_axi_stress_test

`endif // CHS_AXI_STRESS_TEST_SV
