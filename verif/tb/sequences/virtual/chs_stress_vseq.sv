`ifndef CHS_STRESS_VSEQ_SV
`define CHS_STRESS_VSEQ_SV

// ============================================================================
// chs_stress_vseq.sv — Peripheral Stress / Back-to-Back Virtual Sequence
//
// Aşama 4 stress test: Rapidly switches between peripherals via SBA to
// verify there's no AXI crossbar contention, address decode corruption,
// or peripheral state pollution across consecutive SBA operations.
//
// Strategy:
//   1. Initialize all peripherals
//   2. Rapid round-robin: GPIO→UART→SPI→GPIO→UART→SPI... (N rounds)
//   3. Each round writes + reads back a different pattern
//   4. Monitors capture all bus activity for scoreboard verification
// ============================================================================

class chs_stress_vseq extends uvm_sequence;

    `uvm_object_utils(chs_stress_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── Memory Map ───
    localparam bit [31:0] GPIO_BASE      = 32'h0300_5000;
    localparam bit [31:0] UART_BASE      = 32'h0300_2000;
    localparam bit [31:0] SPI_BASE       = 32'h0300_4000;

    localparam bit [31:0] GPIO_DIRECT_OUT = GPIO_BASE + 32'h14;
    localparam bit [31:0] GPIO_DIRECT_OE  = GPIO_BASE + 32'h20;
    localparam bit [31:0] GPIO_DATA_IN    = GPIO_BASE + 32'h10;

    localparam bit [31:0] UART_THR = UART_BASE + 32'h00;
    localparam bit [31:0] UART_LSR = UART_BASE + 32'h14;
    localparam bit [31:0] UART_LCR = UART_BASE + 32'h0C;
    localparam bit [31:0] UART_FCR = UART_BASE + 32'h08;
    localparam bit [31:0] UART_MCR = UART_BASE + 32'h10;
    localparam bit [31:0] UART_DLL = UART_BASE + 32'h00;
    localparam bit [31:0] UART_DLM = UART_BASE + 32'h04;

    localparam bit [31:0] SPI_CONTROL     = SPI_BASE + 32'h10;
    localparam bit [31:0] SPI_STATUS      = SPI_BASE + 32'h14;
    localparam bit [31:0] SPI_CONFIGOPTS0 = SPI_BASE + 32'h18;
    localparam bit [31:0] SPI_CSID        = SPI_BASE + 32'h24;
    localparam bit [31:0] SPI_COMMAND     = SPI_BASE + 32'h28;
    localparam bit [31:0] SPI_TXDATA      = SPI_BASE + 32'h30;
    localparam bit [31:0] SPI_ERR_ENABLE  = SPI_BASE + 32'h34;
    localparam bit [31:0] SPI_ERR_STATUS  = SPI_BASE + 32'h38;

    // Number of stress rounds
    int unsigned num_rounds = 3;

    function new(string name = "chs_stress_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq jtag_seq;
        bit [31:0]    idcode, rdata;

        `uvm_info(get_type_name(),
            "==========================================================", UVM_LOW)
        `uvm_info(get_type_name(),
            "  PERIPHERAL STRESS TEST (Asama 4)                        ", UVM_LOW)
        `uvm_info(get_type_name(),
            "==========================================================", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ── Initialization ──
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ── Init all peripherals ──
        `uvm_info(get_type_name(), "[INIT] Configuring GPIO + UART + SPI", UVM_MEDIUM)
        init_gpio(jtag_seq);
        init_uart(jtag_seq);
        init_spi(jtag_seq);

        // ── Stress rounds ──
        for (int round = 0; round < num_rounds; round++) begin
            bit [31:0] gpio_pattern;
            bit [7:0]  uart_byte;
            bit [7:0]  spi_byte;

            gpio_pattern = 32'h0000_0001 << (round * 8);
            uart_byte    = 8'h41 + round;  // 'A', 'B', 'C'...
            spi_byte     = 8'hF0 + round;

            `uvm_info(get_type_name(), $sformatf(
                "\n---- STRESS ROUND %0d/%0d ----", round+1, num_rounds), UVM_LOW)

            // GPIO write + readback
            `uvm_info(get_type_name(), $sformatf(
                "  GPIO: write 0x%08h", gpio_pattern), UVM_MEDIUM)
            jtag_seq.sba_write32(GPIO_DIRECT_OUT, gpio_pattern, p_sequencer.m_jtag_sqr);
            jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);

            // UART TX (no wait for frame — stress is about rapid SBA switching)
            `uvm_info(get_type_name(), $sformatf(
                "  UART: write 0x%02h to THR", uart_byte), UVM_MEDIUM)
            jtag_seq.sba_write32(UART_THR, {24'h0, uart_byte}, p_sequencer.m_jtag_sqr);

            // SPI TX — write byte, issue command
            `uvm_info(get_type_name(), $sformatf(
                "  SPI: write 0x%02h to TXDATA + COMMAND", spi_byte), UVM_MEDIUM)
            jtag_seq.sba_write32(SPI_TXDATA, {24'h0, spi_byte}, p_sequencer.m_jtag_sqr);
            begin
                bit [31:0] cmd;
                cmd = 32'h0;
                cmd[8:0]   = 9'd0;      // LEN=0 (1 byte)
                cmd[13:12] = 2'b10;     // TX direction
                jtag_seq.sba_write32(SPI_COMMAND, cmd, p_sequencer.m_jtag_sqr);
            end

            // Cross-peripheral readback: read GPIO while SPI transfers
            jtag_seq.sba_read32(GPIO_DATA_IN, rdata, p_sequencer.m_jtag_sqr);
            `uvm_info(get_type_name(), $sformatf(
                "  GPIO: DATA_IN readback = 0x%08h", rdata), UVM_MEDIUM)

            // Wait for SPI transfer + UART frame (aggregate wait)
            // SPI 1-byte = 12µs, UART frame = 87µs. Wait 100µs = 5000 TCK.
            jtag_seq.do_idle(5000, p_sequencer.m_jtag_sqr);

            // Check SPI status
            jtag_seq.sba_read32(SPI_STATUS, rdata, p_sequencer.m_jtag_sqr);
            `uvm_info(get_type_name(), $sformatf(
                "  SPI: STATUS = 0x%08h (ACTIVE=%0b)", rdata, rdata[30]), UVM_MEDIUM)

            // Check UART LSR
            jtag_seq.sba_read32(UART_LSR, rdata, p_sequencer.m_jtag_sqr);
            `uvm_info(get_type_name(), $sformatf(
                "  UART: LSR = 0x%02h (THRE=%0b TEMT=%0b)",
                rdata[7:0], rdata[5], rdata[6]), UVM_MEDIUM)
        end

        // ── Final error check ──
        `uvm_info(get_type_name(), "\n[FINAL] Checking peripheral error states", UVM_MEDIUM)
        jtag_seq.sba_read32(SPI_ERR_STATUS, rdata, p_sequencer.m_jtag_sqr);
        if (rdata != 0)
            `uvm_error(get_type_name(), $sformatf("SPI errors after stress: 0x%08h", rdata))
        else
            `uvm_info(get_type_name(), "SPI: No errors after stress test", UVM_LOW)

        // Final GPIO pattern write
        jtag_seq.sba_write32(GPIO_DIRECT_OUT, 32'hBEEF_CAFE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(200, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(),
            "\n=== PERIPHERAL STRESS TEST COMPLETE ===", UVM_LOW)
    endtask : body

    // ────────────────────────────────────────────────────────────
    virtual task init_gpio(jtag_base_seq jtag_seq);
        jtag_seq.sba_write32(GPIO_DIRECT_OE, 32'hFFFF_FFFF, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(30, p_sequencer.m_jtag_sqr);
    endtask

    virtual task init_uart(jtag_base_seq jtag_seq);
        bit [31:0] lsr_val;
        jtag_seq.sba_write32(UART_LCR, 32'h83, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(UART_DLL, 32'h1B, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(UART_DLM, 32'h00, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(UART_LCR, 32'h03, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(UART_FCR, 32'h07, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(UART_MCR, 32'h03, p_sequencer.m_jtag_sqr);
        // Wait for ready
        jtag_seq.sba_read32(UART_LSR, lsr_val, p_sequencer.m_jtag_sqr);
    endtask

    virtual task init_spi(jtag_base_seq jtag_seq);
        bit [31:0] configopts, control;
        // SW Reset
        control = 32'h0;
        control[30] = 1'b1;
        jtag_seq.sba_write32(SPI_CONTROL, control, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);
        // CONFIGOPTS: Mode 0, CLKDIV=24
        configopts = 32'h0;
        configopts[15:0]  = 16'd24;
        configopts[19:16] = 4'd4;
        configopts[23:20] = 4'd4;
        configopts[27:24] = 4'd4;
        jtag_seq.sba_write32(SPI_CONFIGOPTS0, configopts, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(SPI_CSID, 32'h0, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(SPI_ERR_ENABLE, 32'h1F, p_sequencer.m_jtag_sqr);
        // Enable
        control = 32'h0;
        control[31] = 1'b1;
        control[29] = 1'b1;
        jtag_seq.sba_write32(SPI_CONTROL, control, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);
    endtask

endclass : chs_stress_vseq

`endif // CHS_STRESS_VSEQ_SV
