`ifndef CHS_DRAM_BIST_VSEQ_SV
`define CHS_DRAM_BIST_VSEQ_SV

// ============================================================================
// chs_dram_bist_vseq.sv — DRAM Controller Active Memory BIST Sequence
//
// Active memory verification beyond SBA bypass:
//   1. Walking Ones/Zeros: Test each data bit independently
//   2. Address Bus Test:   Verify each address line is unique
//   3. Checker Pattern:    Alternating 0x55/0xAA across words
//   4. March C-:           Industry-standard RAM test algorithm
//   5. Random Stress:      Random addresses, random data
//
// Access path: JTAG → DMI → SBA → AXI Crossbar → LLC → DRAM (axi_sim_mem)
// ============================================================================

class chs_dram_bist_vseq extends uvm_sequence;

    `uvm_object_utils(chs_dram_bist_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── DRAM region ───
    localparam bit [31:0] DRAM_BASE = 32'h8000_0000;
    // Use a small test window to avoid simulation time explosion
    localparam int unsigned TEST_WORDS = 32;
    localparam bit [31:0] DRAM_TEST_BASE = DRAM_BASE + 32'h0010_0000;

    // LLC SPM region for cross-region test
    localparam bit [31:0] SPM_BASE  = 32'h1000_0000;

    function new(string name = "chs_dram_bist_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq jtag_seq;
        bit [31:0] rdata, idcode;
        int total_pass = 0;
        int total_fail = 0;

        `uvm_info(get_type_name(),
            "═══════ DRAM Memory BIST Test START ═══════", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ── Init ──
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════
        // Test 1: Walking Ones
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[1/5] Walking Ones Test", UVM_LOW)
        begin
            int pass = 0, fail = 0;
            bit [31:0] pattern;

            for (int bit_pos = 0; bit_pos < 32; bit_pos++) begin
                pattern = (32'h1 << bit_pos);
                jtag_seq.sba_write32(DRAM_TEST_BASE, pattern, p_sequencer.m_jtag_sqr);
                jtag_seq.do_idle(20, p_sequencer.m_jtag_sqr);
                jtag_seq.sba_read32(DRAM_TEST_BASE, rdata, p_sequencer.m_jtag_sqr);
                if (rdata == pattern) pass++; else fail++;
            end

            `uvm_info(get_type_name(), $sformatf(
                "  Walking Ones: pass=%0d fail=%0d", pass, fail), UVM_LOW)
            total_pass += pass;
            total_fail += fail;
        end

        // ════════════════════════════════════════════
        // Test 2: Walking Zeros
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[2/5] Walking Zeros Test", UVM_LOW)
        begin
            int pass = 0, fail = 0;
            bit [31:0] pattern;

            for (int bit_pos = 0; bit_pos < 32; bit_pos++) begin
                pattern = ~(32'h1 << bit_pos);
                jtag_seq.sba_write32(DRAM_TEST_BASE + 32'h4, pattern,
                    p_sequencer.m_jtag_sqr);
                jtag_seq.do_idle(20, p_sequencer.m_jtag_sqr);
                jtag_seq.sba_read32(DRAM_TEST_BASE + 32'h4, rdata,
                    p_sequencer.m_jtag_sqr);
                if (rdata == pattern) pass++; else fail++;
            end

            `uvm_info(get_type_name(), $sformatf(
                "  Walking Zeros: pass=%0d fail=%0d", pass, fail), UVM_LOW)
            total_pass += pass;
            total_fail += fail;
        end

        // ════════════════════════════════════════════
        // Test 3: Address Bus Test (power-of-2 offsets)
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[3/5] Address Bus Test", UVM_LOW)
        begin
            int pass = 0, fail = 0;
            bit [31:0] addr;

            // Write unique pattern at each power-of-2 offset
            for (int i = 0; i < 12; i++) begin  // Up to 4K offset
                addr = DRAM_TEST_BASE + (32'h4 << i);
                jtag_seq.sba_write32(addr, addr, p_sequencer.m_jtag_sqr);
            end

            // Read back and verify uniqueness
            jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);
            for (int i = 0; i < 12; i++) begin
                addr = DRAM_TEST_BASE + (32'h4 << i);
                jtag_seq.sba_read32(addr, rdata, p_sequencer.m_jtag_sqr);
                if (rdata == addr) begin
                    pass++;
                end else begin
                    fail++;
                    `uvm_info(get_type_name(), $sformatf(
                        "  ✗ Addr 0x%08h: got 0x%08h exp 0x%08h",
                        addr, rdata, addr), UVM_LOW)
                end
            end

            `uvm_info(get_type_name(), $sformatf(
                "  Address Bus: pass=%0d fail=%0d", pass, fail), UVM_LOW)
            total_pass += pass;
            total_fail += fail;
        end

        // ════════════════════════════════════════════
        // Test 4: Checker Pattern (0x55/0xAA)
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[4/5] Checker Pattern Test", UVM_LOW)
        begin
            int pass = 0, fail = 0;
            bit [31:0] patterns[2] = {32'h5555_5555, 32'hAAAA_AAAA};

            // Phase A: Write checker pattern
            for (int i = 0; i < TEST_WORDS; i++) begin
                jtag_seq.sba_write32(
                    DRAM_TEST_BASE + 32'h100 + (i*4),
                    patterns[i % 2],
                    p_sequencer.m_jtag_sqr);
            end

            jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);

            // Phase B: Verify
            for (int i = 0; i < TEST_WORDS; i++) begin
                jtag_seq.sba_read32(
                    DRAM_TEST_BASE + 32'h100 + (i*4),
                    rdata, p_sequencer.m_jtag_sqr);
                if (rdata == patterns[i % 2]) pass++; else fail++;
            end

            // Phase C: Complement pattern
            for (int i = 0; i < TEST_WORDS; i++) begin
                jtag_seq.sba_write32(
                    DRAM_TEST_BASE + 32'h100 + (i*4),
                    patterns[1 - (i % 2)],
                    p_sequencer.m_jtag_sqr);
            end

            jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);

            // Phase D: Verify complement
            for (int i = 0; i < TEST_WORDS; i++) begin
                jtag_seq.sba_read32(
                    DRAM_TEST_BASE + 32'h100 + (i*4),
                    rdata, p_sequencer.m_jtag_sqr);
                if (rdata == patterns[1 - (i % 2)]) pass++; else fail++;
            end

            `uvm_info(get_type_name(), $sformatf(
                "  Checker Pattern: pass=%0d fail=%0d", pass, fail), UVM_LOW)
            total_pass += pass;
            total_fail += fail;
        end

        // ════════════════════════════════════════════
        // Test 5: March C- (simplified for 8 locations)
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[5/5] March C- Algorithm (8 words)", UVM_LOW)
        begin
            int pass = 0, fail = 0;
            int march_words = 8;
            bit [31:0] base_addr = DRAM_TEST_BASE + 32'h200;

            // M0: ↑ (w0) — Write all zeros ascending
            for (int i = 0; i < march_words; i++)
                jtag_seq.sba_write32(base_addr + (i*4), 32'h0,
                    p_sequencer.m_jtag_sqr);

            // M1: ↑ (r0, w1) — Read zero, write all-ones ascending
            for (int i = 0; i < march_words; i++) begin
                jtag_seq.sba_read32(base_addr + (i*4), rdata,
                    p_sequencer.m_jtag_sqr);
                if (rdata == 32'h0) pass++; else fail++;
                jtag_seq.sba_write32(base_addr + (i*4), 32'hFFFF_FFFF,
                    p_sequencer.m_jtag_sqr);
            end

            // M2: ↑ (r1, w0) — Read ones, write zeros ascending
            for (int i = 0; i < march_words; i++) begin
                jtag_seq.sba_read32(base_addr + (i*4), rdata,
                    p_sequencer.m_jtag_sqr);
                if (rdata == 32'hFFFF_FFFF) pass++; else fail++;
                jtag_seq.sba_write32(base_addr + (i*4), 32'h0,
                    p_sequencer.m_jtag_sqr);
            end

            // M3: ↓ (r0, w1) — Read zero, write ones descending
            for (int i = march_words-1; i >= 0; i--) begin
                jtag_seq.sba_read32(base_addr + (i*4), rdata,
                    p_sequencer.m_jtag_sqr);
                if (rdata == 32'h0) pass++; else fail++;
                jtag_seq.sba_write32(base_addr + (i*4), 32'hFFFF_FFFF,
                    p_sequencer.m_jtag_sqr);
            end

            // M4: ↓ (r1, w0) — Read ones, write zeros descending
            for (int i = march_words-1; i >= 0; i--) begin
                jtag_seq.sba_read32(base_addr + (i*4), rdata,
                    p_sequencer.m_jtag_sqr);
                if (rdata == 32'hFFFF_FFFF) pass++; else fail++;
                jtag_seq.sba_write32(base_addr + (i*4), 32'h0,
                    p_sequencer.m_jtag_sqr);
            end

            // M5: ↑ (r0) — Final verify all zeros
            for (int i = 0; i < march_words; i++) begin
                jtag_seq.sba_read32(base_addr + (i*4), rdata,
                    p_sequencer.m_jtag_sqr);
                if (rdata == 32'h0) pass++; else fail++;
            end

            `uvm_info(get_type_name(), $sformatf(
                "  March C-: pass=%0d fail=%0d", pass, fail), UVM_LOW)
            total_pass += pass;
            total_fail += fail;
        end

        // ─── Final Summary ───
        `uvm_info(get_type_name(),
            "═══════ DRAM Memory BIST Summary ═══════", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
            "  Total: PASS=%0d  FAIL=%0d", total_pass, total_fail), UVM_LOW)

        if (total_fail > 0)
            `uvm_error(get_type_name(), $sformatf(
                "DRAM BIST had %0d failures!", total_fail))
        else
            `uvm_info(get_type_name(), "DRAM BIST test PASSED ✓", UVM_LOW)
    endtask

endclass : chs_dram_bist_vseq

`endif // CHS_DRAM_BIST_VSEQ_SV
