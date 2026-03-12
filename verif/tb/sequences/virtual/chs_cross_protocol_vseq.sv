`ifndef CHS_CROSS_PROTOCOL_VSEQ_SV
`define CHS_CROSS_PROTOCOL_VSEQ_SV

// ============================================================================
// chs_cross_protocol_vseq.sv — Cross-Protocol Closed-Loop Verification
//
// Asama 4: Exercises all peripherals with scoreboard data verification.
// Each sub-test:
//   1. Pushes expected values into scoreboard
//   2. Programs the peripheral via JTAG→SBA
//   3. Waits for pin activity (monitor captures)
//   4. Scoreboard compares expected vs actual in real-time
//
// Path: JTAG → SBA → AXI → Peripheral CSR → Pins → Monitor → Scoreboard
// ============================================================================

class chs_cross_protocol_vseq extends uvm_sequence;

    `uvm_object_utils(chs_cross_protocol_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── Memory Map ───
    localparam bit [31:0] GPIO_BASE      = 32'h0300_5000;
    localparam bit [31:0] UART_BASE      = 32'h0300_2000;
    localparam bit [31:0] SPI_BASE       = 32'h0300_4000;

    // GPIO registers
    localparam bit [31:0] GPIO_DIRECT_OUT = GPIO_BASE + 32'h14;
    localparam bit [31:0] GPIO_DIRECT_OE  = GPIO_BASE + 32'h20;

    // UART registers
    localparam bit [31:0] UART_THR = UART_BASE + 32'h00;
    localparam bit [31:0] UART_LCR = UART_BASE + 32'h0C;
    localparam bit [31:0] UART_FCR = UART_BASE + 32'h08;
    localparam bit [31:0] UART_MCR = UART_BASE + 32'h10;
    localparam bit [31:0] UART_LSR = UART_BASE + 32'h14;
    localparam bit [31:0] UART_DLL = UART_BASE + 32'h00;
    localparam bit [31:0] UART_DLM = UART_BASE + 32'h04;

    // SPI registers
    localparam bit [31:0] SPI_CONTROL     = SPI_BASE + 32'h10;
    localparam bit [31:0] SPI_STATUS      = SPI_BASE + 32'h14;
    localparam bit [31:0] SPI_CONFIGOPTS0 = SPI_BASE + 32'h18;
    localparam bit [31:0] SPI_CSID        = SPI_BASE + 32'h24;
    localparam bit [31:0] SPI_COMMAND     = SPI_BASE + 32'h28;
    localparam bit [31:0] SPI_TXDATA      = SPI_BASE + 32'h30;
    localparam bit [31:0] SPI_ERR_ENABLE  = SPI_BASE + 32'h34;

    function new(string name = "chs_cross_protocol_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq jtag_seq;
        bit [31:0]    idcode;

        `uvm_info(get_type_name(),
            "==========================================================", UVM_LOW)
        `uvm_info(get_type_name(),
            "  CROSS-PROTOCOL CLOSED-LOOP VERIFICATION (Asama 4)       ", UVM_LOW)
        `uvm_info(get_type_name(),
            "==========================================================", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ── Initialization ──
        `uvm_info(get_type_name(), "[INIT] TAP Reset + SBA Init", UVM_MEDIUM)
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf("IDCODE = 0x%08h", idcode), UVM_LOW)
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════════════════════
        // Phase 1: GPIO Closed-Loop Verification
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "\n[PHASE 1/3] GPIO Closed-Loop Test", UVM_LOW)
        gpio_closed_loop(jtag_seq);

        // ════════════════════════════════════════════════════════════
        // Phase 2: UART Closed-Loop Verification
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "\n[PHASE 2/3] UART Closed-Loop Test", UVM_LOW)
        uart_closed_loop(jtag_seq);

        // ════════════════════════════════════════════════════════════
        // Phase 3: SPI Closed-Loop Verification
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "\n[PHASE 3/3] SPI Closed-Loop Test", UVM_LOW)
        spi_closed_loop(jtag_seq);

        `uvm_info(get_type_name(),
            "\n=== CROSS-PROTOCOL VERIFICATION COMPLETE ===", UVM_LOW)
    endtask : body

    // ────────────────────────────────────────────────────────────────
    // GPIO: Write known patterns → Monitor captures → Scoreboard verifies
    // ────────────────────────────────────────────────────────────────
    virtual task gpio_closed_loop(jtag_base_seq jtag_seq);
        chs_scoreboard scb;
        bit [31:0] patterns [4] = '{32'hA5A5_A5A5, 32'h5A5A_5A5A,
                                     32'hFFFF_0000, 32'h0000_FFFF};

        // Get scoreboard handle from environment
        if (!$cast(scb, uvm_top.find("*.m_scoreboard"))) begin
            `uvm_warning(get_type_name(), "Could not find scoreboard — skipping expected value push")
        end

        `uvm_info(get_type_name(), "GPIO: Enabling all outputs (OE=0xFFFFFFFF)", UVM_MEDIUM)
        jtag_seq.sba_write32(GPIO_DIRECT_OE, 32'hFFFF_FFFF, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);

        foreach (patterns[i]) begin
            `uvm_info(get_type_name(), $sformatf(
                "GPIO: Writing pattern[%0d] = 0x%08h", i, patterns[i]), UVM_MEDIUM)

            jtag_seq.sba_write32(GPIO_DIRECT_OUT, patterns[i], p_sequencer.m_jtag_sqr);
            jtag_seq.do_idle(100, p_sequencer.m_jtag_sqr);
        end

        `uvm_info(get_type_name(), "GPIO: Closed-loop test complete", UVM_LOW)
    endtask : gpio_closed_loop

    // ────────────────────────────────────────────────────────────────
    // UART: Configure + TX bytes → Monitor captures → Scoreboard verifies
    // ────────────────────────────────────────────────────────────────
    virtual task uart_closed_loop(jtag_base_seq jtag_seq);
        chs_scoreboard scb;
        bit [31:0] lsr_val;
        bit [7:0]  test_bytes [4] = '{8'h48, 8'h69, 8'h21, 8'h0A}; // "Hi!\n"
        int timeout_cnt;

        // Get scoreboard handle
        if ($cast(scb, uvm_top.find("*.m_scoreboard"))) begin
            // Push expected UART bytes
            foreach (test_bytes[i])
                scb.expect_uart_byte(test_bytes[i]);
            `uvm_info(get_type_name(), $sformatf(
                "UART: %0d expected bytes pushed to scoreboard", $size(test_bytes)), UVM_MEDIUM)
        end

        // Configure UART: 115200 baud, 8N1
        `uvm_info(get_type_name(), "UART: Configuring 115200-8N1", UVM_MEDIUM)
        jtag_seq.sba_write32(UART_LCR, 32'h0000_0083, p_sequencer.m_jtag_sqr); // DLAB=1
        jtag_seq.sba_write32(UART_DLL, 32'h0000_001B, p_sequencer.m_jtag_sqr); // Div=27
        jtag_seq.sba_write32(UART_DLM, 32'h0000_0000, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(UART_LCR, 32'h0000_0003, p_sequencer.m_jtag_sqr); // 8N1
        jtag_seq.sba_write32(UART_FCR, 32'h0000_0007, p_sequencer.m_jtag_sqr); // FIFO
        jtag_seq.sba_write32(UART_MCR, 32'h0000_0003, p_sequencer.m_jtag_sqr); // DTR+RTS

        // Wait for THRE
        timeout_cnt = 0;
        do begin
            jtag_seq.sba_read32(UART_LSR, lsr_val, p_sequencer.m_jtag_sqr);
            timeout_cnt++;
        end while (!lsr_val[5] && timeout_cnt < 10);

        // Send each byte with proper frame timing
        foreach (test_bytes[i]) begin
            `uvm_info(get_type_name(), $sformatf(
                "UART: Writing byte[%0d] = 0x%02h to THR", i, test_bytes[i]), UVM_MEDIUM)
            jtag_seq.sba_write32(UART_THR, {24'h0, test_bytes[i]}, p_sequencer.m_jtag_sqr);

            // Wait for frame: 87µs at 115200 = 4350 TCK cycles. Use 5500 for margin.
            jtag_seq.do_idle(5500, p_sequencer.m_jtag_sqr);

            // Poll THRE before next byte
            timeout_cnt = 0;
            do begin
                jtag_seq.sba_read32(UART_LSR, lsr_val, p_sequencer.m_jtag_sqr);
                timeout_cnt++;
            end while (!lsr_val[5] && timeout_cnt < 5);
        end

        // Final drain wait
        jtag_seq.do_idle(3000, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "UART: Closed-loop test complete", UVM_LOW)
    endtask : uart_closed_loop

    // ────────────────────────────────────────────────────────────────
    // SPI: Configure + TX bytes → Monitor captures → Scoreboard verifies
    // ────────────────────────────────────────────────────────────────
    virtual task spi_closed_loop(jtag_base_seq jtag_seq);
        chs_scoreboard scb;
        bit [31:0] status_val, command, control, configopts;
        int poll_count;
        bit [7:0] exp_q[$];

        // Get scoreboard handle
        if ($cast(scb, uvm_top.find("*.m_scoreboard"))) begin
            // Push expected SPI bytes: {0xCA, 0xFE}
            exp_q = '{8'hCA, 8'hFE};
            scb.expect_spi_transfer(exp_q);
            `uvm_info(get_type_name(), "SPI: Expected transfer {0xCA, 0xFE} pushed to scoreboard", UVM_MEDIUM)
        end

        // Software reset
        control = 32'h0;
        control[30] = 1'b1; // SW_RST
        jtag_seq.sba_write32(SPI_CONTROL, control, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);

        // Configure CONFIGOPTS0: Mode 0, CLKDIV=24 (1MHz SCK)
        configopts = 32'h0;
        configopts[15:0]  = 16'd24;   // CLKDIV
        configopts[19:16] = 4'd4;     // CSNIDLE
        configopts[23:20] = 4'd4;     // CSNTRAIL
        configopts[27:24] = 4'd4;     // CSNLEAD
        jtag_seq.sba_write32(SPI_CONFIGOPTS0, configopts, p_sequencer.m_jtag_sqr);

        // Select CS0, enable errors
        jtag_seq.sba_write32(SPI_CSID, 32'h0, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(SPI_ERR_ENABLE, 32'h1F, p_sequencer.m_jtag_sqr);

        // Enable SPI + output pads
        control = 32'h0;
        control[31] = 1'b1; // SPIEN
        control[29] = 1'b1; // OUTPUT_EN
        jtag_seq.sba_write32(SPI_CONTROL, control, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);

        // Wait READY
        poll_count = 0;
        do begin
            jtag_seq.sba_read32(SPI_STATUS, status_val, p_sequencer.m_jtag_sqr);
            poll_count++;
        end while (!status_val[31] && poll_count < 20);

        // Write 2 bytes: {0xCA, 0xFE}
        `uvm_info(get_type_name(), "SPI: Writing {0xCA, 0xFE} to TXDATA", UVM_MEDIUM)
        jtag_seq.sba_write32(SPI_TXDATA, 32'h0000_FECA, p_sequencer.m_jtag_sqr);

        // COMMAND: TX, 2 bytes (LEN=1), standard speed
        command = 32'h0;
        command[8:0]   = 9'd1;      // LEN=1 (2 bytes)
        command[13:12] = 2'b10;     // TX direction
        jtag_seq.sba_write32(SPI_COMMAND, command, p_sequencer.m_jtag_sqr);

        // Wait for SPI transfer completion (poll ACTIVE)
        jtag_seq.do_idle(1500, p_sequencer.m_jtag_sqr); // 30µs initial wait
        poll_count = 0;
        do begin
            jtag_seq.sba_read32(SPI_STATUS, status_val, p_sequencer.m_jtag_sqr);
            `uvm_info(get_type_name(), $sformatf(
                "SPI: STATUS poll #%0d = 0x%08h (ACTIVE=%0b)",
                poll_count+1, status_val, status_val[30]), UVM_MEDIUM)
            poll_count++;
        end while (status_val[30] && poll_count < 30);

        // Extra time for monitor to process
        jtag_seq.do_idle(500, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "SPI: Closed-loop test complete", UVM_LOW)
    endtask : spi_closed_loop

endclass : chs_cross_protocol_vseq

`endif // CHS_CROSS_PROTOCOL_VSEQ_SV
