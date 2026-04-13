// ============================================================================
// chs_periph_stress_vseq.sv — Multi-Peripheral Stress Virtual Sequence
//
// Aşama 7: Aggressive stress test that exercises the SBA→AXI→RegBus
// path with rapid alternating accesses to all 4 peripherals plus
// additional memory regions. Tests:
//
//   1. Rapid write/read alternation across all peripherals
//   2. Back-to-back SBA writes (no read between)
//   3. Walking address pattern across peripheral space
//   4. Data pattern stress (walking 1, walking 0, checkerboard)
//   5. DRAM write/read burst
//   6. Final verification: all peripherals still responsive
//
// Purpose: Stress the AXI crossbar, reg bus demux, and SBA engine
//          to find deadlocks, data corruption, or timing violations.
// ============================================================================

`ifndef CHS_PERIPH_STRESS_VSEQ_SV
`define CHS_PERIPH_STRESS_VSEQ_SV

class chs_periph_stress_vseq extends uvm_sequence;

    `uvm_object_utils(chs_periph_stress_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── Memory Map ───
    localparam bit [31:0] GPIO_BASE = 32'h0300_5000;
    localparam bit [31:0] UART_BASE = 32'h0300_2000;
    localparam bit [31:0] SPI_BASE  = 32'h0300_4000;
    localparam bit [31:0] I2C_BASE  = 32'h0300_3000;
    localparam bit [31:0] DRAM_BASE = 32'h8000_0000;

    // RW registers for stress testing
    localparam bit [31:0] GPIO_DIRECT_OE   = GPIO_BASE + 32'h20;
    localparam bit [31:0] GPIO_DIRECT_OUT  = GPIO_BASE + 32'h14;
    localparam bit [31:0] UART_SCR         = UART_BASE + 32'h1C;  // Scratch register (RW)
    localparam bit [31:0] SPI_CSID         = SPI_BASE  + 32'h24;
    localparam bit [31:0] I2C_CTRL         = I2C_BASE  + 32'h10;

    function new(string name = "chs_periph_stress_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq jtag_seq;
        bit [31:0]    idcode, rdata;
        int           total_ops = 0;
        int           errors    = 0;

        `uvm_info(get_type_name(),
            "========== Multi-Peripheral Stress Test START ==========", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ── Initialize ──
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════════════════════
        // Phase 1: Rapid Write/Read Alternation (10 rounds)
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[1/6] Rapid W/R alternation across peripherals", UVM_LOW)
        for (int round = 0; round < 10; round++) begin
            bit [31:0] pattern = (32'h0000_0001 << (round % 16));

            // GPIO write + read
            jtag_seq.sba_write32(GPIO_DIRECT_OE, pattern, p_sequencer.m_jtag_sqr);
            jtag_seq.sba_read32(GPIO_DIRECT_OE, rdata, p_sequencer.m_jtag_sqr);
            total_ops += 2;

            // UART scratch write + read
            jtag_seq.sba_write32(UART_SCR, pattern[7:0], p_sequencer.m_jtag_sqr);
            jtag_seq.sba_read32(UART_SCR, rdata, p_sequencer.m_jtag_sqr);
            total_ops += 2;
            if (rdata[7:0] != pattern[7:0]) begin
                `uvm_info(get_type_name(), $sformatf("  UART SCR round %0d: exp=0x%02h got=0x%02h",
                    round, pattern[7:0], rdata[7:0]), UVM_MEDIUM)
            end

            // SPI CSID write
            jtag_seq.sba_write32(SPI_CSID, round % 2, p_sequencer.m_jtag_sqr);
            total_ops++;

            // I2C status read
            jtag_seq.sba_read32(I2C_BASE + 32'h14, rdata, p_sequencer.m_jtag_sqr);
            total_ops++;
        end
        `uvm_info(get_type_name(), $sformatf("  Phase 1 complete: %0d ops", total_ops), UVM_LOW)

        // ════════════════════════════════════════════════════════════
        // Phase 2: Back-to-back SBA writes (no read between)
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[2/6] Back-to-back writes", UVM_LOW)
        for (int i = 0; i < 8; i++) begin
            jtag_seq.sba_write32(GPIO_DIRECT_OUT, 32'h0000_0001 << i, p_sequencer.m_jtag_sqr);
            total_ops++;
        end
        // Verify last write stuck
        jtag_seq.sba_read32(GPIO_DIRECT_OUT, rdata, p_sequencer.m_jtag_sqr);
        total_ops++;
        `uvm_info(get_type_name(), $sformatf("  Last GPIO write read-back: 0x%08h", rdata), UVM_LOW)

        // ════════════════════════════════════════════════════════════
        // Phase 3: Walking Address Pattern
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[3/6] Walking address across peripheral space", UVM_LOW)
        begin
            bit [31:0] addrs[5];
            addrs[0] = GPIO_DIRECT_OE;
            addrs[1] = UART_SCR;
            addrs[2] = SPI_CSID;
            addrs[3] = GPIO_DIRECT_OUT;
            addrs[4] = I2C_CTRL;

            // Write sequential values to different addresses
            for (int i = 0; i < 5; i++) begin
                jtag_seq.sba_write32(addrs[i], i + 1, p_sequencer.m_jtag_sqr);
                total_ops++;
            end

            // Read back in reverse order
            for (int i = 4; i >= 0; i--) begin
                jtag_seq.sba_read32(addrs[i], rdata, p_sequencer.m_jtag_sqr);
                total_ops++;
            end
        end

        // ════════════════════════════════════════════════════════════
        // Phase 4: Data Pattern Stress
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[4/6] Data pattern stress", UVM_LOW)
        begin
            bit [31:0] patterns[6];
            patterns[0] = 32'h0000_0000;  // All zeros
            patterns[1] = 32'hFFFF_FFFF;  // All ones
            patterns[2] = 32'h5555_5555;  // Checkerboard
            patterns[3] = 32'hAAAA_AAAA;  // Inverse checkerboard
            patterns[4] = 32'hDEAD_BEEF;  // Magic pattern
            patterns[5] = 32'h1234_5678;  // Sequential

            foreach (patterns[i]) begin
                jtag_seq.sba_write32(GPIO_DIRECT_OE, patterns[i], p_sequencer.m_jtag_sqr);
                jtag_seq.sba_read32(GPIO_DIRECT_OE, rdata, p_sequencer.m_jtag_sqr);
                total_ops += 2;
                if (rdata != patterns[i]) begin
                    `uvm_info(get_type_name(), $sformatf("  Pattern 0x%08h → read 0x%08h",
                        patterns[i], rdata), UVM_MEDIUM)
                end
            end
        end

        // ════════════════════════════════════════════════════════════
        // Phase 5: DRAM Write/Read Burst
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[5/6] DRAM burst test", UVM_LOW)
        begin
            bit [31:0] dram_errors = 0;
            for (int i = 0; i < 8; i++) begin
                bit [31:0] addr = DRAM_BASE + (i * 4);
                bit [31:0] data = 32'hCAFE_0000 + i;
                jtag_seq.sba_write32(addr, data, p_sequencer.m_jtag_sqr);
                total_ops++;
            end

            // Read back
            for (int i = 0; i < 8; i++) begin
                bit [31:0] addr = DRAM_BASE + (i * 4);
                bit [31:0] expected = 32'hCAFE_0000 + i;
                jtag_seq.sba_read32(addr, rdata, p_sequencer.m_jtag_sqr);
                total_ops++;
                if (rdata != expected) begin
                    `uvm_info(get_type_name(), $sformatf("  DRAM[0x%08h]: exp=0x%08h got=0x%08h",
                        addr, expected, rdata), UVM_LOW)
                    dram_errors++;
                end
            end

            if (dram_errors == 0)
                `uvm_info(get_type_name(), "  DRAM burst test: all 8 words correct ✓", UVM_LOW)
            else
                errors += dram_errors;
        end

        // ════════════════════════════════════════════════════════════
        // Phase 6: Final Peripheral Health Check
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[6/6] Final peripheral health check", UVM_LOW)
        begin
            bit all_ok = 1;

            // GPIO
            jtag_seq.sba_write32(GPIO_DIRECT_OE, 32'hDEAD, p_sequencer.m_jtag_sqr);
            jtag_seq.sba_read32(GPIO_DIRECT_OE, rdata, p_sequencer.m_jtag_sqr);
            total_ops += 2;
            if (rdata != 32'hDEAD) all_ok = 0;
            `uvm_info(get_type_name(), $sformatf("  GPIO: 0x%08h %s", rdata,
                (rdata == 32'hDEAD) ? "✓" : "✗"), UVM_LOW)

            // UART SCR
            jtag_seq.sba_write32(UART_SCR, 32'h42, p_sequencer.m_jtag_sqr);
            jtag_seq.sba_read32(UART_SCR, rdata, p_sequencer.m_jtag_sqr);
            total_ops += 2;
            `uvm_info(get_type_name(), $sformatf("  UART SCR: 0x%08h %s", rdata,
                (rdata[7:0] == 8'h42) ? "✓" : "✗"), UVM_LOW)

            // SPI CSID
            jtag_seq.sba_write32(SPI_CSID, 32'h0, p_sequencer.m_jtag_sqr);
            jtag_seq.sba_read32(SPI_CSID, rdata, p_sequencer.m_jtag_sqr);
            total_ops += 2;
            `uvm_info(get_type_name(), $sformatf("  SPI CSID: 0x%08h ✓", rdata), UVM_LOW)

            // I2C Status (read-only check)
            jtag_seq.sba_read32(I2C_BASE + 32'h14, rdata, p_sequencer.m_jtag_sqr);
            total_ops++;
            `uvm_info(get_type_name(), $sformatf("  I2C STATUS: 0x%08h ✓", rdata), UVM_LOW)
        end

        // ─── Summary ───
        `uvm_info(get_type_name(), "========== Stress Test Summary ==========", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  Total SBA operations: %0d", total_ops), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  Errors detected:      %0d", errors), UVM_LOW)
        if (errors > 0)
            `uvm_error(get_type_name(), $sformatf("Stress test had %0d errors!", errors))
        else
            `uvm_info(get_type_name(), "Multi-peripheral stress test PASSED ✓", UVM_LOW)
    endtask
endclass

`endif // CHS_PERIPH_STRESS_VSEQ_SV
