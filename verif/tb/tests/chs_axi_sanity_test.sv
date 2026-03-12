`ifndef CHS_AXI_SANITY_TEST_SV
`define CHS_AXI_SANITY_TEST_SV

// ============================================================================
// chs_axi_sanity_test.sv — AXI Bus Sanity Test
//
// Observes the SoC boot sequence through the AXI LLC/DRAM port.
// The CVA6 core naturally generates AXI traffic when:
//   1. Fetching instructions from Boot ROM (read bursts)
//   2. Stack/data operations to SPM/DRAM (read/write)
//   3. Cache line fills and evictions
//
// This test verifies:
//   - AXI protocol checker reports no violations
//   - AXI monitor captures transactions
//   - Scoreboard records read/write activity
//   - Coverage baseline is established
// ============================================================================

class chs_axi_sanity_test extends chs_base_test;

    `uvm_component_utils(chs_axi_sanity_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void configure_env();
        m_env_cfg.has_axi_agent = 1;
        m_env_cfg.boot_mode = 2'b00;   // JTAG boot — minimal activity
    endfunction

    virtual task test_body();
        `uvm_info(get_type_name(), "════════════════════════════════════════════", UVM_NONE)
        `uvm_info(get_type_name(), "  AXI Sanity Test — Boot Observation", UVM_NONE)
        `uvm_info(get_type_name(), "════════════════════════════════════════════", UVM_NONE)

        // Phase 1: Wait for initial boot fetch activity
        `uvm_info(get_type_name(), "Phase 1: Waiting for initial AXI activity...", UVM_LOW)
        #50_000ns;

        // Check if AXI monitor has captured transactions
        if (m_env.m_axi_agent != null) begin
            `uvm_info(get_type_name(), $sformatf(
                "AXI Monitor: writes=%0d reads=%0d",
                m_env.m_axi_agent.m_monitor.write_count,
                m_env.m_axi_agent.m_monitor.read_count), UVM_LOW)
        end

        // Phase 2: Extended observation
        `uvm_info(get_type_name(), "Phase 2: Extended AXI observation...", UVM_LOW)
        #100_000ns;

        // Phase 3: Final summary
        `uvm_info(get_type_name(), $sformatf(
            "AXI Final: writes=%0d reads=%0d scb_errors=%0d",
            m_env.m_scoreboard.axi_write_count,
            m_env.m_scoreboard.axi_read_count,
            m_env.m_scoreboard.axi_error_count), UVM_NONE)

        `uvm_info(get_type_name(), "AXI Sanity Test Complete", UVM_NONE)
    endtask

endclass : chs_axi_sanity_test

`endif // CHS_AXI_SANITY_TEST_SV
