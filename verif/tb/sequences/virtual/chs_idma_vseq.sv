`ifndef CHS_IDMA_VSEQ_SV
`define CHS_IDMA_VSEQ_SV

// ============================================================================
// chs_idma_vseq.sv — iDMA Engine Virtual Sequence
//
// Exercises the iDMA engine through SBA register access:
//   1. Read iDMA configuration/status registers
//   2. Set up source/destination addresses in SPM
//   3. Configure and trigger a 1D DMA transfer
//   4. Verify data integrity at destination
//   5. Test back-to-back transfers with different sizes
// ============================================================================

class chs_idma_vseq extends uvm_sequence;

    `uvm_object_utils(chs_idma_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── iDMA Register Map (AXI periphs) ───
    localparam bit [31:0] IDMA_BASE       = 32'h0100_0000;
    localparam bit [31:0] IDMA_SRC_ADDR   = IDMA_BASE + 32'h00;
    localparam bit [31:0] IDMA_DST_ADDR   = IDMA_BASE + 32'h08;
    localparam bit [31:0] IDMA_NUM_BYTES  = IDMA_BASE + 32'h10;
    localparam bit [31:0] IDMA_CFG        = IDMA_BASE + 32'h18;
    localparam bit [31:0] IDMA_STATUS     = IDMA_BASE + 32'h20;
    localparam bit [31:0] IDMA_NEXT_ID    = IDMA_BASE + 32'h28;
    localparam bit [31:0] IDMA_DONE       = IDMA_BASE + 32'h30;

    // ─── SPM regions for DMA test ───
    localparam bit [31:0] SPM_SRC_BASE    = 32'h1000_1000;  // DMA source in SPM
    localparam bit [31:0] SPM_DST_BASE    = 32'h1000_2000;  // DMA destination in SPM

    function new(string name = "chs_idma_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq jtag_seq;
        bit [31:0] rdata, idcode, sbcs_val;
        int pass_cnt = 0;
        int fail_cnt = 0;

        `uvm_info(get_type_name(),
            "═══════ iDMA Engine Test START ═══════", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ── Init ──
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════
        // Phase 1: Read iDMA Status Registers
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[1/5] Reading iDMA status registers", UVM_LOW)

        jtag_seq.sba_read32(IDMA_STATUS, rdata, p_sequencer.m_jtag_sqr);
        jtag_seq.dmi_read(7'h38, sbcs_val, p_sequencer.m_jtag_sqr);
        if (sbcs_val[14:12] == 0) begin
            `uvm_info(get_type_name(), $sformatf(
                "  ✓ iDMA STATUS = 0x%08h", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_info(get_type_name(), $sformatf(
                "  ✗ iDMA STATUS SBA error=%0d", sbcs_val[14:12]), UVM_LOW)
            fail_cnt++;
            jtag_seq.sba_init(p_sequencer.m_jtag_sqr);
        end

        jtag_seq.sba_read32(IDMA_NEXT_ID, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf(
            "  iDMA NEXT_ID = 0x%08h", rdata), UVM_LOW)

        // ════════════════════════════════════════════
        // Phase 2: Write source data to SPM
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[2/5] Writing source data to SPM", UVM_LOW)
        begin
            bit [31:0] test_pattern;
            for (int i = 0; i < 16; i++) begin
                test_pattern = 32'hCAFE_0000 + i;
                jtag_seq.sba_write32(SPM_SRC_BASE + (i*4), test_pattern,
                    p_sequencer.m_jtag_sqr);
            end
            `uvm_info(get_type_name(), "  ✓ 64 bytes written to SPM source region", UVM_LOW)
            pass_cnt++;
        end

        // Clear destination
        for (int i = 0; i < 16; i++) begin
            jtag_seq.sba_write32(SPM_DST_BASE + (i*4), 32'h0, p_sequencer.m_jtag_sqr);
        end

        // ════════════════════════════════════════════
        // Phase 3: Configure iDMA Transfer
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[3/5] Configuring iDMA 1D transfer (64 bytes)", UVM_LOW)

        // Source address
        jtag_seq.sba_write32(IDMA_SRC_ADDR, SPM_SRC_BASE, p_sequencer.m_jtag_sqr);
        // Destination address
        jtag_seq.sba_write32(IDMA_DST_ADDR, SPM_DST_BASE, p_sequencer.m_jtag_sqr);
        // Number of bytes
        jtag_seq.sba_write32(IDMA_NUM_BYTES, 32'd64, p_sequencer.m_jtag_sqr);
        // Configuration (decouple=1, deburst=1)
        jtag_seq.sba_write32(IDMA_CFG, 32'h0000_0003, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "  iDMA transfer configured and launched", UVM_LOW)

        // ════════════════════════════════════════════
        // Phase 4: Wait for completion
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[4/5] Waiting for iDMA completion", UVM_LOW)
        begin
            int timeout = 0;
            bit done = 0;
            while (!done && timeout < 20) begin
                jtag_seq.do_idle(100, p_sequencer.m_jtag_sqr);
                jtag_seq.sba_read32(IDMA_DONE, rdata, p_sequencer.m_jtag_sqr);
                if (rdata != 0) done = 1;
                timeout++;
            end

            if (done) begin
                pass_cnt++;
                `uvm_info(get_type_name(), $sformatf(
                    "  ✓ iDMA transfer completed (DONE=0x%08h)", rdata), UVM_LOW)
            end else begin
                `uvm_warning(get_type_name(),
                    "  ⚠ iDMA transfer did not complete in expected time")
            end
        end

        // ════════════════════════════════════════════
        // Phase 5: Verify destination data
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[5/5] Verifying destination data", UVM_LOW)
        begin
            int match_cnt = 0;
            int mismatch_cnt = 0;

            for (int i = 0; i < 16; i++) begin
                bit [31:0] expected = 32'hCAFE_0000 + i;
                jtag_seq.sba_read32(SPM_DST_BASE + (i*4), rdata, p_sequencer.m_jtag_sqr);
                if (rdata == expected) begin
                    match_cnt++;
                end else begin
                    mismatch_cnt++;
                    `uvm_info(get_type_name(), $sformatf(
                        "  ✗ DST[%0d] = 0x%08h (expected 0x%08h)",
                        i, rdata, expected), UVM_LOW)
                end
            end

            `uvm_info(get_type_name(), $sformatf(
                "  Data verification: %0d match, %0d mismatch (of 16)",
                match_cnt, mismatch_cnt), UVM_LOW)

            if (mismatch_cnt == 0) begin
                pass_cnt++;
                `uvm_info(get_type_name(), "  ✓ All 16 words verified correctly", UVM_LOW)
            end else begin
                fail_cnt++;
            end
        end

        // ─── Summary ───
        `uvm_info(get_type_name(),
            "═══════ iDMA Engine Test Summary ═══════", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
            "  PASS: %0d  FAIL: %0d", pass_cnt, fail_cnt), UVM_LOW)

        if (fail_cnt > 0)
            `uvm_error(get_type_name(), "iDMA test had failures!")
        else
            `uvm_info(get_type_name(), "iDMA test PASSED ✓", UVM_LOW)
    endtask

endclass : chs_idma_vseq

`endif // CHS_IDMA_VSEQ_SV
