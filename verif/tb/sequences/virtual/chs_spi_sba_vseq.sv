`ifndef CHS_SPI_SBA_VSEQ_SV
`define CHS_SPI_SBA_VSEQ_SV

// ============================================================================
// chs_spi_sba_vseq.sv — SPI Host SBA System Bus Access Virtual Sequence
//
// Exercises the full SoC path for SPI Host peripheral:
//   JTAG → DMI → Debug Module → SBA → AXI Crossbar
//     → AXI-to-Regbus Bridge → SPI Host CSR → SPI Pins
//
// OpenTitan spi_host register map (base 0x0300_4000):
//   INTR_STATE  = 0x00   INTR_ENABLE = 0x04   INTR_TEST  = 0x08
//   ALERT_TEST  = 0x0C   CONTROL     = 0x10   STATUS     = 0x14
//   CONFIGOPTS0 = 0x18   CONFIGOPTS1 = 0x1C   CONFIGOPTS2= 0x20
//   CSID        = 0x24   COMMAND     = 0x28
//   RXDATA      = 0x2C   TXDATA      = 0x30
//   ERROR_ENABLE= 0x34   ERROR_STATUS= 0x38   EVENT_ENABLE=0x3C
//
// Test strategy:
//   1. Verify SPI Host accessibility via STATUS register read
//   2. Configure CONFIGOPTS for SPI Mode 0 (CPOL=0, CPHA=0), slow clock
//   3. Enable SPI Host (CONTROL.SPIEN=1, CONTROL.OUTPUT_EN=1)
//   4. Write TX data into TXDATA FIFO
//   5. Issue COMMAND to transmit (DIRECTION=TX, LEN=N-1)
//   6. Monitor STATUS for completion, observe SPI pins via SPI Monitor
// ============================================================================

class chs_spi_sba_vseq extends uvm_sequence;

    `uvm_object_utils(chs_spi_sba_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── SPI Host Register Addresses ───
    localparam bit [31:0] SPI_BASE        = 32'h0300_4000;
    localparam bit [31:0] SPI_INTR_STATE  = SPI_BASE + 32'h00;
    localparam bit [31:0] SPI_INTR_ENABLE = SPI_BASE + 32'h04;
    localparam bit [31:0] SPI_CONTROL     = SPI_BASE + 32'h10;
    localparam bit [31:0] SPI_STATUS      = SPI_BASE + 32'h14;
    localparam bit [31:0] SPI_CONFIGOPTS0 = SPI_BASE + 32'h18;
    localparam bit [31:0] SPI_CSID        = SPI_BASE + 32'h24;
    localparam bit [31:0] SPI_COMMAND     = SPI_BASE + 32'h28;
    localparam bit [31:0] SPI_RXDATA      = SPI_BASE + 32'h2C;
    localparam bit [31:0] SPI_TXDATA      = SPI_BASE + 32'h30;
    localparam bit [31:0] SPI_ERR_ENABLE  = SPI_BASE + 32'h34;
    localparam bit [31:0] SPI_ERR_STATUS  = SPI_BASE + 32'h38;
    localparam bit [31:0] SPI_EVT_ENABLE  = SPI_BASE + 32'h3C;

    // ─── CONTROL Register Bit Positions ───
    localparam int CTRL_SPIEN     = 31;   // SPI block enable
    localparam int CTRL_SW_RST    = 30;   // Software reset
    localparam int CTRL_OUTPUT_EN = 29;   // Enable SPI output pads

    // ─── COMMAND Register Fields ───
    // [8:0]=LEN, [9]=CSAAT, [11:10]=SPEED, [13:12]=DIRECTION
    localparam bit [1:0] CMD_DIR_DUMMY = 2'b00;
    localparam bit [1:0] CMD_DIR_RX    = 2'b01;
    localparam bit [1:0] CMD_DIR_TX    = 2'b10;
    localparam bit [1:0] CMD_DIR_BIDIR = 2'b11;

    localparam bit [1:0] CMD_SPEED_STD  = 2'b00;
    localparam bit [1:0] CMD_SPEED_DUAL = 2'b01;
    localparam bit [1:0] CMD_SPEED_QUAD = 2'b10;

    function new(string name = "chs_spi_sba_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq  jtag_seq;
        bit [31:0]     rdata;
        bit [31:0]     idcode;

        `uvm_info(get_type_name(),
                  "===== SPI Host SBA Test START =====", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ── Step 1: TAP Reset + SBA Init ──
        `uvm_info(get_type_name(), "[1/6] TAP Reset + SBA Init", UVM_MEDIUM)
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf("IDCODE = 0x%08h", idcode), UVM_LOW)
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ── Step 2: Probe SPI Host Accessibility ──
        `uvm_info(get_type_name(), "[2/6] Probing SPI Host accessibility (STATUS reg)", UVM_MEDIUM)
        spi_probe_test(jtag_seq);

        // ── Step 3: Configure SPI Host ──
        `uvm_info(get_type_name(), "[3/6] Configuring SPI Host", UVM_MEDIUM)
        spi_configure(jtag_seq);

        // ── Step 4: Single Byte TX Test ──
        `uvm_info(get_type_name(), "[4/6] SPI Single Byte TX", UVM_MEDIUM)
        spi_tx_single(jtag_seq);

        // ── Step 5: Multi-Byte TX Test ──
        `uvm_info(get_type_name(), "[5/6] SPI Multi-Byte TX", UVM_MEDIUM)
        spi_tx_multi(jtag_seq);

        // ── Step 6: Status & Error Check ──
        `uvm_info(get_type_name(), "[6/6] Final Status Check", UVM_MEDIUM)
        spi_final_check(jtag_seq);

        `uvm_info(get_type_name(),
                  "===== SPI Host SBA Test COMPLETE =====", UVM_LOW)
    endtask : body

    // ────────────────────────────────────────────────────────────────
    // Probe SPI Host — read STATUS register
    // After reset, STATUS should show TXEMPTY=1 (bit28) and READY=1 (bit31)
    // ────────────────────────────────────────────────────────────────
    virtual task spi_probe_test(jtag_base_seq jtag_seq);
        bit [31:0] status_val;

        jtag_seq.sba_read32(SPI_STATUS, status_val, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
            $sformatf("SPI STATUS = 0x%08h (READY=%0b ACTIVE=%0b TXEMPTY=%0b RXEMPTY=%0b)",
            status_val, status_val[31], status_val[30], status_val[28], status_val[24]),
            UVM_LOW)

        if (status_val[28] !== 1'b1)
            `uvm_warning(get_type_name(),
                $sformatf("SPI: TXEMPTY not set after reset (STATUS=0x%08h)", status_val))

        if (status_val === 32'h0) begin
            `uvm_warning(get_type_name(), "SPI: STATUS reads all-zero — peripheral may not be synthesized")
        end
    endtask : spi_probe_test

    // ────────────────────────────────────────────────────────────────
    // Configure SPI Host for standard SPI Mode 0 operation
    // ────────────────────────────────────────────────────────────────
    virtual task spi_configure(jtag_base_seq jtag_seq);
        bit [31:0] configopts;
        bit [31:0] control;

        // 1) Software reset to clear any leftover state
        control = 32'h0;
        control[CTRL_SW_RST] = 1'b1;
        jtag_seq.sba_write32(SPI_CONTROL, control, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);

        // 2) Configure CONFIGOPTS0 for CS0:
        //    CPOL=0, CPHA=0, CLKDIV=24 (SCK = 50MHz / (2*(24+1)) = 1 MHz)
        //    CSNIDLE=4, CSNLEAD=4, CSNTRAIL=4
        configopts = 32'h0;
        configopts[15:0]  = 16'd24;   // CLKDIV = 24
        configopts[19:16] = 4'd4;     // CSNIDLE = 4
        configopts[23:20] = 4'd4;     // CSNTRAIL = 4
        configopts[27:24] = 4'd4;     // CSNLEAD = 4
        configopts[29]    = 1'b0;     // FULLCYC = 0
        configopts[30]    = 1'b0;     // CPHA = 0
        configopts[31]    = 1'b0;     // CPOL = 0
        `uvm_info(get_type_name(),
            $sformatf("SPI: CONFIGOPTS0 = 0x%08h (CPOL=0 CPHA=0 CLKDIV=24 → 1MHz SCK)", configopts), UVM_MEDIUM)
        jtag_seq.sba_write32(SPI_CONFIGOPTS0, configopts, p_sequencer.m_jtag_sqr);

        // 3) Select CS0
        jtag_seq.sba_write32(SPI_CSID, 32'h0000_0000, p_sequencer.m_jtag_sqr);

        // 4) Enable error reporting (all errors)
        jtag_seq.sba_write32(SPI_ERR_ENABLE, 32'h0000_001F, p_sequencer.m_jtag_sqr);

        // 5) Enable SPI Host + output pads
        control = 32'h0;
        control[CTRL_SPIEN]     = 1'b1;  // Enable SPI block
        control[CTRL_OUTPUT_EN] = 1'b1;  // Enable output pads
        `uvm_info(get_type_name(),
            $sformatf("SPI: CONTROL = 0x%08h (SPIEN=1 OUTPUT_EN=1)", control), UVM_MEDIUM)
        jtag_seq.sba_write32(SPI_CONTROL, control, p_sequencer.m_jtag_sqr);

        // 6) Wait for SPI Host to become ready
        jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "SPI: Configuration complete", UVM_MEDIUM)
    endtask : spi_configure

    // ────────────────────────────────────────────────────────────────
    // Wait for SPI transfer to complete by polling STATUS.ACTIVE
    // At TCK=20ns, each sba_read32 ≈ 10µs. Max 50 polls = 500µs timeout.
    // ────────────────────────────────────────────────────────────────
    virtual task wait_spi_idle(jtag_base_seq jtag_seq, string context_str = "");
        bit [31:0] status_val;
        int poll_count;

        // First, give the SPI Host time to start the transfer
        // SCK=1MHz → 1 byte takes 12µs (LEAD+8clk+TRAIL). At TCK=20ns, 1000 idle = 20µs.
        jtag_seq.do_idle(1000, p_sequencer.m_jtag_sqr);

        // Then poll STATUS until ACTIVE clears
        poll_count = 0;
        do begin
            jtag_seq.sba_read32(SPI_STATUS, status_val, p_sequencer.m_jtag_sqr);
            `uvm_info(get_type_name(),
                $sformatf("SPI: %s STATUS poll #%0d = 0x%08h (ACTIVE=%0b READY=%0b TXEMPTY=%0b)",
                context_str, poll_count+1, status_val, status_val[30], status_val[31], status_val[28]),
                UVM_MEDIUM)
            poll_count++;
            if (poll_count > 50) begin
                `uvm_error(get_type_name(),
                    $sformatf("SPI: %s transfer timeout! STATUS=0x%08h after %0d polls",
                    context_str, status_val, poll_count))
                break;
            end
        end while (status_val[30]); // ACTIVE bit

        if (!status_val[30])
            `uvm_info(get_type_name(),
                $sformatf("SPI: %s transfer completed after %0d polls (STATUS=0x%08h)",
                context_str, poll_count, status_val), UVM_LOW)

        // Extra idle to ensure SPI monitor fully captures the CS deassertion
        jtag_seq.do_idle(200, p_sequencer.m_jtag_sqr);
    endtask : wait_spi_idle

    // ────────────────────────────────────────────────────────────────
    // Single byte TX: write 0xA5 into TXDATA, issue TX command
    // SPI Monitor should capture the byte on the SPI bus
    // ────────────────────────────────────────────────────────────────
    virtual task spi_tx_single(jtag_base_seq jtag_seq);
        bit [31:0] status_val;
        bit [31:0] command;
        int poll_count;

        // Wait for READY
        poll_count = 0;
        do begin
            jtag_seq.sba_read32(SPI_STATUS, status_val, p_sequencer.m_jtag_sqr);
            poll_count++;
            if (poll_count > 20) begin
                `uvm_warning(get_type_name(),
                    $sformatf("SPI: READY not set after %0d polls (STATUS=0x%08h)", poll_count, status_val))
                break;
            end
        end while (!status_val[31]);

        // Write TX data: 0xA5
        `uvm_info(get_type_name(), "SPI: Writing 0xA5 to TXDATA FIFO", UVM_MEDIUM)
        jtag_seq.sba_write32(SPI_TXDATA, 32'h0000_00A5, p_sequencer.m_jtag_sqr);

        // Issue COMMAND: TX direction, 1 byte (LEN=0), standard speed, no CSAAT
        command = 32'h0;
        command[8:0]   = 9'd0;           // LEN = 0 (1 byte)
        command[9]     = 1'b0;           // CSAAT = 0 (de-assert CS after)
        command[11:10] = CMD_SPEED_STD;  // Standard SPI
        command[13:12] = CMD_DIR_TX;     // TX direction
        `uvm_info(get_type_name(),
            $sformatf("SPI: COMMAND = 0x%08h (TX, 1 byte, standard)", command), UVM_MEDIUM)
        jtag_seq.sba_write32(SPI_COMMAND, command, p_sequencer.m_jtag_sqr);

        // ─── CRITICAL: Wait for SPI transfer to fully complete ───
        // SPI 1-byte @ 1MHz = CSNLEAD(2µs) + 8 SCK(8µs) + CSNTRAIL(2µs) = 12µs
        // Old: do_idle(200) = 4µs → TOO SHORT! Transfer never completes before check.
        // New: Poll STATUS.ACTIVE until it clears
        wait_spi_idle(jtag_seq, "SingleTX");

        `uvm_info(get_type_name(), "SPI: Single byte TX complete", UVM_MEDIUM)
    endtask : spi_tx_single

    // ────────────────────────────────────────────────────────────────
    // Multi-byte TX: send 4 bytes {0xDE, 0xAD, 0xBE, 0xEF}
    // ────────────────────────────────────────────────────────────────
    virtual task spi_tx_multi(jtag_base_seq jtag_seq);
        bit [31:0] status_val;
        bit [31:0] command;
        int poll_count;

        // Wait for READY
        poll_count = 0;
        do begin
            jtag_seq.sba_read32(SPI_STATUS, status_val, p_sequencer.m_jtag_sqr);
            poll_count++;
            if (poll_count > 20) break;
        end while (!status_val[31]);

        // Write 4 bytes into TXDATA FIFO (each write pushes 1 word = 4 bytes)
        // For byte-level control, we write one byte at a time
        `uvm_info(get_type_name(), "SPI: Writing {0xDE, 0xAD, 0xBE, 0xEF} to TXDATA", UVM_MEDIUM)
        jtag_seq.sba_write32(SPI_TXDATA, 32'hEFBEADDE, p_sequencer.m_jtag_sqr);

        // Issue COMMAND: TX direction, 4 bytes (LEN=3), standard speed
        command = 32'h0;
        command[8:0]   = 9'd3;           // LEN = 3 (4 bytes)
        command[9]     = 1'b0;           // CSAAT = 0
        command[11:10] = CMD_SPEED_STD;  // Standard SPI
        command[13:12] = CMD_DIR_TX;     // TX direction
        `uvm_info(get_type_name(),
            $sformatf("SPI: COMMAND = 0x%08h (TX, 4 bytes, standard)", command), UVM_MEDIUM)
        jtag_seq.sba_write32(SPI_COMMAND, command, p_sequencer.m_jtag_sqr);

        // ─── CRITICAL: Wait for SPI transfer to fully complete ───
        // SPI 4-byte @ 1MHz = CSNLEAD(2µs) + 32 SCK(32µs) + CSNTRAIL(2µs) = 36µs
        // Old: do_idle(500) = 10µs → TOO SHORT! Only ~28% of transfer completes.
        // New: Poll STATUS.ACTIVE until it clears
        wait_spi_idle(jtag_seq, "MultiTX");

        `uvm_info(get_type_name(), "SPI: Multi-byte TX complete", UVM_MEDIUM)
    endtask : spi_tx_multi

    // ────────────────────────────────────────────────────────────────
    // Final status and error check
    // ────────────────────────────────────────────────────────────────
    virtual task spi_final_check(jtag_base_seq jtag_seq);
        bit [31:0] err_status;
        bit [31:0] status_val;

        jtag_seq.sba_read32(SPI_ERR_STATUS, err_status, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_read32(SPI_STATUS, status_val, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(),
            $sformatf("SPI: Final STATUS=0x%08h ERROR_STATUS=0x%08h", status_val, err_status), UVM_LOW)

        if (err_status != 0) begin
            `uvm_error(get_type_name(),
                $sformatf("SPI: Errors detected! ERROR_STATUS=0x%08h", err_status))
            // Clear errors (W1C)
            jtag_seq.sba_write32(SPI_ERR_STATUS, err_status, p_sequencer.m_jtag_sqr);
        end else begin
            `uvm_info(get_type_name(), "SPI: No errors detected — all transfers clean", UVM_LOW)
        end
    endtask : spi_final_check

endclass : chs_spi_sba_vseq

`endif // CHS_SPI_SBA_VSEQ_SV
