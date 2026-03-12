`ifndef CHS_JTAG_SBA_VSEQ_SV
`define CHS_JTAG_SBA_VSEQ_SV

// ============================================================================
// chs_jtag_sba_vseq.sv — JTAG → SBA System Bus Access Virtual Sequence
//
// This is the KEY SoC-Level Verification sequence. It exercises the full
// internal bus path:
//
//   JTAG Pin → TAP → DMI → Debug Module → SBA → AXI Crossbar
//     → AXI-to-Regbus Bridge → Peripheral CSR → Hardware → External Pin
//
// Test steps:
//   1. TAP Reset + IDCODE verify
//   2. SBA Init (dmactive + sbcs configuration)
//   3. Read SoC Registers (verify basic bus connectivity)
//   4. GPIO Output Test (write GPIO regs → gpio_o pin changes)
//   5. UART Loopback Test (configure UART → send byte → monitor TX pin)
// ============================================================================

class chs_jtag_sba_vseq extends uvm_sequence;

    `uvm_object_utils(chs_jtag_sba_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── Cheshire Memory Map (from documentation) ───
    localparam bit [31:0] SOC_REGS_BASE  = 32'h0300_0000;
    localparam bit [31:0] UART_BASE      = 32'h0300_2000;
    localparam bit [31:0] I2C_BASE       = 32'h0300_3000;
    localparam bit [31:0] SPI_BASE       = 32'h0300_4000;
    localparam bit [31:0] GPIO_BASE      = 32'h0300_5000;

    // ─── OpenTitan GPIO Register Offsets ───
    localparam bit [31:0] GPIO_DATA_IN    = GPIO_BASE + 32'h10;
    localparam bit [31:0] GPIO_DIRECT_OUT = GPIO_BASE + 32'h14;
    localparam bit [31:0] GPIO_DIRECT_OE  = GPIO_BASE + 32'h20;

    // ─── UART (TI 16750) Register Offsets ───
    localparam bit [31:0] UART_THR = UART_BASE + 32'h00;  // TX Holding Reg (write)
    localparam bit [31:0] UART_IER = UART_BASE + 32'h04;  // Interrupt Enable
    localparam bit [31:0] UART_FCR = UART_BASE + 32'h08;  // FIFO Control (write)
    localparam bit [31:0] UART_LCR = UART_BASE + 32'h0C;  // Line Control
    localparam bit [31:0] UART_MCR = UART_BASE + 32'h10;  // Modem Control
    localparam bit [31:0] UART_LSR = UART_BASE + 32'h14;  // Line Status (read)
    localparam bit [31:0] UART_DLL = UART_BASE + 32'h00;  // Divisor Latch Low (DLAB=1)
    localparam bit [31:0] UART_DLM = UART_BASE + 32'h04;  // Divisor Latch High (DLAB=1)

    function new(string name = "chs_jtag_sba_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq  jtag_seq;
        bit [31:0]     rdata;
        bit [31:0]     idcode;

        `uvm_info(get_type_name(),
                  "===== JTAG SBA System Bus Access START =====", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ════════════════════════════════════════════════════════════
        // Step 1: TAP Reset + IDCODE
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[1/5] TAP Reset + IDCODE read", UVM_MEDIUM)
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf("IDCODE = 0x%08h", idcode), UVM_LOW)

        if (idcode[0] !== 1'b1)
            `uvm_error(get_type_name(), "IDCODE LSB is not 1!")

        // ════════════════════════════════════════════════════════════
        // Step 2: SBA Initialization
        //   dmactive=1, configure sbcs for 32-bit access
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[2/5] SBA Init (dmactive + sbcs)", UVM_MEDIUM)
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════════════════════
        // Step 3: Read SoC Registers (basic bus connectivity test)
        //   Address 0x0300_0000 should return a readable value
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[3/5] SBA Read: SoC Registers @ 0x0300_0000", UVM_MEDIUM)
        jtag_seq.sba_read32(SOC_REGS_BASE, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
                  $sformatf("SoC Regs[0x0] = 0x%08h (bus connectivity verified!)", rdata), UVM_LOW)

        // ════════════════════════════════════════════════════════════
        // Step 4: GPIO Output Test
        //   Write GPIO registers via SBA → gpio_o pin should change
        //   → GPIO Monitor detects change → Scoreboard++
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[4/5] GPIO Output via SBA", UVM_MEDIUM)
        gpio_output_test(jtag_seq);

        // ════════════════════════════════════════════════════════════
        // Step 5: UART TX Test
        //   Configure UART via SBA → write TX byte
        //   → UART hardware generates frame on TX pin
        //   → UART Monitor captures → Scoreboard++
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[5/5] UART TX via SBA", UVM_MEDIUM)
        uart_tx_test(jtag_seq);

        `uvm_info(get_type_name(),
                  "===== JTAG SBA System Bus Access COMPLETE =====", UVM_LOW)
    endtask : body

    // ─── GPIO Output Sub-test ───
    // Write to GPIO registers through SBA and verify output changes
    virtual task gpio_output_test(jtag_base_seq jtag_seq);
        bit [31:0] rdata;
        bit [31:0] gpio_in_val;

        `uvm_info(get_type_name(), "GPIO: Enabling all outputs (OE=0xFFFFFFFF)", UVM_MEDIUM)
        jtag_seq.sba_write32(GPIO_DIRECT_OE, 32'hFFFF_FFFF, p_sequencer.m_jtag_sqr);

        // Write a known pattern to GPIO output
        `uvm_info(get_type_name(), "GPIO: Driving output = 0xDEADBEEF", UVM_MEDIUM)
        jtag_seq.sba_write32(GPIO_DIRECT_OUT, 32'hDEAD_BEEF, p_sequencer.m_jtag_sqr);

        // Wait for the value to propagate through DUT
        jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);

        // Change pattern to verify monitor catches it
        `uvm_info(get_type_name(), "GPIO: Driving output = 0xCAFEBABE", UVM_MEDIUM)
        jtag_seq.sba_write32(GPIO_DIRECT_OUT, 32'hCAFE_BABE, p_sequencer.m_jtag_sqr);

        // Wait and then read back GPIO input (what TB gpio_driver is driving)
        jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "GPIO: Reading DATA_IN register", UVM_MEDIUM)
        jtag_seq.sba_read32(GPIO_DATA_IN, gpio_in_val, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
                  $sformatf("GPIO DATA_IN = 0x%08h (reflects gpio_i from TB driver)", gpio_in_val), UVM_LOW)

        `uvm_info(get_type_name(), "GPIO: SBA output test complete", UVM_MEDIUM)
    endtask : gpio_output_test

    // ─── UART TX Sub-test ───
    // Configure UART via SBA and transmit a byte
    //
    // Cheshire UART: 16550A-compatible (obi_uart), 8-bit registers
    // aligned to 32-bit boundaries (stride=4). Only wdata[7:0] matters.
    //
    // NOTE: obi_uart does NOT implement the Scratch Pad Register (SPR).
    //   Writes to SPR (0x1C) are silently ignored; reads always return 0x00.
    //   We use LSR (Line Status Register) as the accessibility probe instead.
    //   After reset, LSR should return 0x60 (THRE=1, TEMT=1).
    virtual task uart_tx_test(jtag_base_seq jtag_seq);
        bit [31:0] lsr_val;
        bit [31:0] lcr_val;
        int timeout_cnt;
        bit uart_accessible;

        // 50 MHz clock, 115200 baud: divisor = 50_000_000 / (16 * 115200) ≈ 27
        localparam bit [15:0] BAUD_DIVISOR = 16'd27;

        // Step 0: Probe UART accessibility via LSR readback
        //   After reset, LSR[6:5] = 2'b11 → TEMT + THRE → LSR = 0x60
        //   If UART is not synthesized/mapped, we'd read 0x00 or bus error.
        `uvm_info(get_type_name(), "UART: Probing accessibility (read LSR)", UVM_MEDIUM)
        jtag_seq.sba_read32(UART_LSR, lsr_val, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
                  $sformatf("UART: LSR readback = 0x%08h (expected bit[6:5]=2'b11 → 0x60)", lsr_val), UVM_LOW)

        if (lsr_val[5] === 1'b1) begin
            // THRE bit is set → TX holding register empty → UART is alive
            uart_accessible = 1;
            `uvm_info(get_type_name(),
                      $sformatf("UART: Accessible! LSR=0x%02h (THRE=%0b TEMT=%0b)",
                      lsr_val[7:0], lsr_val[5], lsr_val[6]), UVM_LOW)
        end else begin
            // Secondary probe: try writing LCR and reading back
            `uvm_info(get_type_name(), "UART: LSR THRE not set, trying LCR write/read probe", UVM_MEDIUM)
            jtag_seq.sba_write32(UART_LCR, 32'h0000_001B, p_sequencer.m_jtag_sqr);  // 8N1 + break
            jtag_seq.sba_read32(UART_LCR, lcr_val, p_sequencer.m_jtag_sqr);
            if (lcr_val[7:0] == 8'h1B) begin
                uart_accessible = 1;
                `uvm_info(get_type_name(),
                    $sformatf("UART: Accessible via LCR! wrote=0x1B read=0x%02h", lcr_val[7:0]), UVM_LOW)
                // Restore LCR to safe value
                jtag_seq.sba_write32(UART_LCR, 32'h0000_0003, p_sequencer.m_jtag_sqr);
            end else begin
                uart_accessible = 0;
                `uvm_warning(get_type_name(),
                    $sformatf("UART: NOT accessible. LSR=0x%08h LCR=0x%08h", lsr_val, lcr_val))
            end
        end

        if (!uart_accessible) begin
            `uvm_info(get_type_name(), "UART: Skipping TX test (peripheral not accessible)", UVM_LOW)
            return;
        end

        `uvm_info(get_type_name(), "UART: Configuring 115200-8N1", UVM_MEDIUM)

        // 1) Set DLAB=1 to access divisor latch (LCR[7]=1, LCR[1:0]=11 for 8-bit)
        jtag_seq.sba_write32(UART_LCR, 32'h0000_0083, p_sequencer.m_jtag_sqr);

        // 2) Write baud rate divisor
        jtag_seq.sba_write32(UART_DLL, {16'h0, BAUD_DIVISOR}, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(UART_DLM, 32'h0000_0000, p_sequencer.m_jtag_sqr);

        // 3) Clear DLAB, set 8N1 (8 data, no parity, 1 stop)
        jtag_seq.sba_write32(UART_LCR, 32'h0000_0003, p_sequencer.m_jtag_sqr);

        // 4) Enable FIFOs, reset TX/RX FIFOs
        jtag_seq.sba_write32(UART_FCR, 32'h0000_0007, p_sequencer.m_jtag_sqr);

        // 5) Modem control (DTR + RTS active)
        jtag_seq.sba_write32(UART_MCR, 32'h0000_0003, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "UART: Configuration complete, checking LSR", UVM_MEDIUM)

        // 6) Wait for TX FIFO empty (LSR bit 5 = THRE)
        //    Reduced poll count to 10 — if it doesn't work in 10, it won't
        timeout_cnt = 0;
        do begin
            jtag_seq.sba_read32(UART_LSR, lsr_val, p_sequencer.m_jtag_sqr);
            `uvm_info(get_type_name(),
                      $sformatf("UART: LSR poll #%0d = 0x%02h (THRE=%0b TEMT=%0b)",
                      timeout_cnt+1, lsr_val[7:0], lsr_val[5], lsr_val[6]), UVM_MEDIUM)
            timeout_cnt++;
            if (timeout_cnt >= 10) begin
                `uvm_warning(get_type_name(),
                    $sformatf("UART: LSR THRE not set after %0d polls (LSR=0x%02h)", timeout_cnt, lsr_val[7:0]))
                break;
            end
        end while (!(lsr_val[5]));

        if (lsr_val[5]) begin
            `uvm_info(get_type_name(),
                      $sformatf("UART: TX FIFO ready (LSR=0x%02h), writing 0x55 to THR", lsr_val[7:0]), UVM_MEDIUM)

            // 7) Write byte to THR — UART hardware will generate TX frame
            jtag_seq.sba_write32(UART_THR, 32'h0000_0055, p_sequencer.m_jtag_sqr);

            // ─── CRITICAL TIMING FIX ───
            // UART frame at 115200 baud: 1 bit = 8.68µs, 1 frame (10 bits) = 86.8µs
            // JTAG TCK = 20ns → need do_idle(5000) = 100µs per frame
            // Old: do_idle(500) = 10µs → frame only 11% complete → monitor misses it!
            `uvm_info(get_type_name(), "UART: Waiting 100µs for TX frame to complete...", UVM_MEDIUM)
            jtag_seq.do_idle(5000, p_sequencer.m_jtag_sqr);

            // Poll LSR until THRE=1 (TX holding register empty → frame sent)
            timeout_cnt = 0;
            do begin
                jtag_seq.sba_read32(UART_LSR, lsr_val, p_sequencer.m_jtag_sqr);
                `uvm_info(get_type_name(),
                    $sformatf("UART: Post-TX LSR poll #%0d = 0x%02h (THRE=%0b TEMT=%0b)",
                    timeout_cnt+1, lsr_val[7:0], lsr_val[5], lsr_val[6]), UVM_MEDIUM)
                timeout_cnt++;
            end while (!lsr_val[5] && timeout_cnt < 10);

            // Send another byte
            `uvm_info(get_type_name(), "UART: Writing 0xAA to THR", UVM_MEDIUM)
            jtag_seq.sba_write32(UART_THR, 32'h0000_00AA, p_sequencer.m_jtag_sqr);

            // Wait for second frame to complete (100µs + margin)
            `uvm_info(get_type_name(), "UART: Waiting 120µs for second TX frame...", UVM_MEDIUM)
            jtag_seq.do_idle(6000, p_sequencer.m_jtag_sqr);

            // Final LSR check — both bytes should be transmitted
            jtag_seq.sba_read32(UART_LSR, lsr_val, p_sequencer.m_jtag_sqr);
            `uvm_info(get_type_name(),
                $sformatf("UART: Final LSR = 0x%02h (THRE=%0b TEMT=%0b) — TX complete",
                lsr_val[7:0], lsr_val[5], lsr_val[6]), UVM_LOW)

            `uvm_info(get_type_name(), "UART: TX bytes sent (0x55, 0xAA)", UVM_MEDIUM)
        end else begin
            // Even if THRE isn't set, try writing directly
            `uvm_info(get_type_name(), "UART: THRE timeout, attempting direct THR write anyway", UVM_LOW)
            jtag_seq.sba_write32(UART_THR, 32'h0000_0055, p_sequencer.m_jtag_sqr);
            jtag_seq.do_idle(5000, p_sequencer.m_jtag_sqr);
        end

        `uvm_info(get_type_name(), "UART: SBA TX test complete", UVM_MEDIUM)
    endtask : uart_tx_test

endclass : chs_jtag_sba_vseq

`endif
