`ifndef CHS_AXI_PROTOCOL_TEST_SV
`define CHS_AXI_PROTOCOL_TEST_SV

// ============================================================================
// chs_axi_protocol_test.sv — AXI Protocol Compliance Test
//
// Focused on verifying AXI protocol rules:
//   - All 50+ SVA assertions in chs_axi_protocol_checker pass
//   - Cover properties are hit (baseline coverage)
//   - Multiple address regions are accessed
//   - Various burst types are exercised
//
// Uses JTAG SBA to probe different memory regions and trigger
// various AXI transaction patterns.
// ============================================================================

class chs_axi_protocol_test extends chs_base_test;

    `uvm_component_utils(chs_axi_protocol_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void configure_env();
        m_env_cfg.has_axi_agent  = 1;
        m_env_cfg.has_jtag_agent = 1;
        m_timeout = 3ms;
    endfunction

    virtual task test_body();
        jtag_base_seq  jtag_seq;
        bit [31:0]     rdata;

        `uvm_info(get_type_name(), "════════════════════════════════════════════", UVM_NONE)
        `uvm_info(get_type_name(), "  AXI Protocol Compliance Test", UVM_NONE)
        `uvm_info(get_type_name(), "════════════════════════════════════════════", UVM_NONE)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // Phase 1: JTAG init
        `uvm_info(get_type_name(), "Phase 1: JTAG initialization...", UVM_LOW)
        jtag_seq.do_reset(m_env.m_virt_sqr.m_jtag_sqr);
        jtag_seq.sba_init(m_env.m_virt_sqr.m_jtag_sqr);
        #10_000ns;

        // Phase 2: Access Boot ROM region (read-only)
        `uvm_info(get_type_name(), "Phase 2: Boot ROM reads...", UVM_LOW)
        for (int i = 0; i < 8; i++) begin
            jtag_seq.sba_read32(32'h0200_0000 + (i * 4), rdata, m_env.m_virt_sqr.m_jtag_sqr);
            `uvm_info(get_type_name(), $sformatf("ROM[%0d] = 0x%08h", i, rdata), UVM_MEDIUM)
        end
        #20_000ns;

        // Phase 3: Access CLINT region
        `uvm_info(get_type_name(), "Phase 3: CLINT register access...", UVM_LOW)
        jtag_seq.sba_read32(32'h0204_0000, rdata, m_env.m_virt_sqr.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf("CLINT mtime = 0x%08h", rdata), UVM_LOW)
        #10_000ns;

        // Phase 4: SPM write/read patterns
        `uvm_info(get_type_name(), "Phase 4: SPM write/read patterns...", UVM_LOW)
        for (int i = 0; i < 16; i++) begin
            jtag_seq.sba_write32(32'h1400_0000 + (i * 4), 32'hCAFE_0000 | (i * 32'h100), m_env.m_virt_sqr.m_jtag_sqr);
        end
        #30_000ns;

        // Read back SPM
        for (int i = 0; i < 16; i++) begin
            jtag_seq.sba_read32(32'h1400_0000 + (i * 4), rdata, m_env.m_virt_sqr.m_jtag_sqr);
            `uvm_info(get_type_name(), $sformatf("SPM[%0d] = 0x%08h", i, rdata), UVM_MEDIUM)
        end
        #30_000ns;

        // Phase 5: DRAM region access
        `uvm_info(get_type_name(), "Phase 5: DRAM write/read...", UVM_LOW)
        for (int i = 0; i < 8; i++) begin
            jtag_seq.sba_write32(32'h8000_0000 + (i * 4), 32'hABCD_0000 + i, m_env.m_virt_sqr.m_jtag_sqr);
        end
        #20_000ns;

        for (int i = 0; i < 8; i++) begin
            jtag_seq.sba_read32(32'h8000_0000 + (i * 4), rdata, m_env.m_virt_sqr.m_jtag_sqr);
            `uvm_info(get_type_name(), $sformatf("DRAM[%0d] = 0x%08h", i, rdata), UVM_MEDIUM)
        end
        #30_000ns;

        // Phase 6: Final stats
        `uvm_info(get_type_name(), $sformatf(
            "FINAL: AXI W=%0d R=%0d RAW_match=%0d RAW_mismatch=%0d errors=%0d",
            m_env.m_scoreboard.axi_write_count,
            m_env.m_scoreboard.axi_read_count,
            m_env.m_scoreboard.axi_raw_match,
            m_env.m_scoreboard.axi_raw_mismatch,
            m_env.m_scoreboard.axi_error_count), UVM_NONE)

        `uvm_info(get_type_name(), "AXI Protocol Compliance Test Complete", UVM_NONE)
    endtask

endclass : chs_axi_protocol_test

`endif // CHS_AXI_PROTOCOL_TEST_SV
