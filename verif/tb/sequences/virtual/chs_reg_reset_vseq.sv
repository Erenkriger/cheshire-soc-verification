// ============================================================================
// chs_reg_reset_vseq.sv — Register Reset Value Verification Sequence
//
// Aşama 7: After SoC reset, reads all known peripheral registers via
// SBA and verifies they contain their documented reset values.
//
// Sources for reset values:
//   GPIO (OpenTitan): All registers reset to 0x0
//   UART (16550):     LSR resets to 0x60 (TX empty + TX hold empty)
//   SPI (OpenTitan):  Most reset to 0x0, STATUS has idle bit
//   I2C (OpenTitan):  CTRL/STATUS have specific reset values
// ============================================================================

`ifndef CHS_REG_RESET_VSEQ_SV
`define CHS_REG_RESET_VSEQ_SV

class chs_reg_reset_vseq extends uvm_sequence;

    `uvm_object_utils(chs_reg_reset_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── Memory Map ───
    localparam bit [31:0] GPIO_BASE = 32'h0300_5000;
    localparam bit [31:0] UART_BASE = 32'h0300_2000;
    localparam bit [31:0] SPI_BASE  = 32'h0300_4000;
    localparam bit [31:0] I2C_BASE  = 32'h0300_3000;

    function new(string name = "chs_reg_reset_vseq");
        super.new(name);
    endfunction

    // ── Helper: Check a single register's reset value ──
    task check_reg_reset(
        jtag_base_seq       jtag_seq,
        string              name,
        bit [31:0]          addr,
        bit [31:0]          expected_val,
        bit [31:0]          mask,          // Only check bits where mask=1
        ref int             pass_cnt,
        ref int             fail_cnt,
        input uvm_sequencer_base sqr
    );
        bit [31:0] rdata;
        jtag_seq.sba_read32(addr, rdata, sqr);

        if ((rdata & mask) == (expected_val & mask)) begin
            `uvm_info(get_type_name(), $sformatf("  ✓ %-25s [0x%08h] = 0x%08h (exp 0x%08h)",
                name, addr, rdata, expected_val), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_info(get_type_name(), $sformatf("  ✗ %-25s [0x%08h] = 0x%08h (exp 0x%08h, mask 0x%08h)",
                name, addr, rdata, expected_val, mask), UVM_LOW)
            fail_cnt++;
        end
    endtask

    virtual task body();
        jtag_base_seq jtag_seq;
        bit [31:0]    idcode;
        int           pass_cnt = 0;
        int           fail_cnt = 0;

        `uvm_info(get_type_name(),
            "========== Register Reset Value Test START ==========", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ── Initialize JTAG→SBA (fresh, no prior writes) ──
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf("IDCODE = 0x%08h", idcode), UVM_LOW)
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════════════════════
        // GPIO Register Reset Values (OpenTitan GPIO)
        // All registers reset to 0x0
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "─── GPIO Registers ───", UVM_LOW)

        check_reg_reset(jtag_seq, "GPIO INTR_STATE",
            GPIO_BASE + 32'h00, 32'h0, 32'hFFFF_FFFF,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        check_reg_reset(jtag_seq, "GPIO INTR_ENABLE",
            GPIO_BASE + 32'h04, 32'h0, 32'hFFFF_FFFF,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        check_reg_reset(jtag_seq, "GPIO DIRECT_OUT",
            GPIO_BASE + 32'h14, 32'h0, 32'hFFFF_FFFF,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        check_reg_reset(jtag_seq, "GPIO DIRECT_OE",
            GPIO_BASE + 32'h20, 32'h0, 32'hFFFF_FFFF,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        check_reg_reset(jtag_seq, "GPIO CTRL_EN_RISING",
            GPIO_BASE + 32'h2C, 32'h0, 32'hFFFF_FFFF,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        check_reg_reset(jtag_seq, "GPIO CTRL_EN_FALLING",
            GPIO_BASE + 32'h30, 32'h0, 32'hFFFF_FFFF,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════════════════════
        // UART Register Reset Values (16550)
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "─── UART Registers ───", UVM_LOW)

        // IER resets to 0x00
        check_reg_reset(jtag_seq, "UART IER",
            UART_BASE + 32'h04, 32'h0, 32'h0F,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        // LCR resets to 0x00
        check_reg_reset(jtag_seq, "UART LCR",
            UART_BASE + 32'h0C, 32'h0, 32'hFF,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        // MCR resets to 0x00
        check_reg_reset(jtag_seq, "UART MCR",
            UART_BASE + 32'h10, 32'h0, 32'h1F,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        // LSR resets to 0x60 (THRE=1, TEMT=1: TX empty)
        check_reg_reset(jtag_seq, "UART LSR",
            UART_BASE + 32'h14, 32'h60, 32'h7F,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        // MSR is read-only, upper nibble reflects modem inputs (CTS,DSR,RI,DCD)
        // In Cheshire SoC these pins are pulled high → upper nibble = 0xF
        check_reg_reset(jtag_seq, "UART MSR",
            UART_BASE + 32'h18, 32'hF0, 32'hF0,  // Upper nibble: modem pins high
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        // SCR resets to 0x00
        check_reg_reset(jtag_seq, "UART SCR",
            UART_BASE + 32'h1C, 32'h0, 32'hFF,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════════════════════
        // SPI Register Reset Values (OpenTitan SPI Host)
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "─── SPI Registers ───", UVM_LOW)

        check_reg_reset(jtag_seq, "SPI INTR_STATE",
            SPI_BASE + 32'h00, 32'h0, 32'h0000_0003,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        check_reg_reset(jtag_seq, "SPI INTR_ENABLE",
            SPI_BASE + 32'h04, 32'h0, 32'h0000_0003,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        // CTRL resets to 0x7F (TX_WATERMARK=127) with SPIEN=0
        check_reg_reset(jtag_seq, "SPI CTRL",
            SPI_BASE + 32'h10, 32'h0, 32'h8000_0000,  // Check SPIEN bit only
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        // CSID resets to 0
        check_reg_reset(jtag_seq, "SPI CSID",
            SPI_BASE + 32'h24, 32'h0, 32'hFFFF_FFFF,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════════════════════
        // I2C Register Reset Values (OpenTitan I2C)
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "─── I2C Registers ───", UVM_LOW)

        check_reg_reset(jtag_seq, "I2C INTR_STATE",
            I2C_BASE + 32'h00, 32'h0, 32'h0000_7FFF,
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        check_reg_reset(jtag_seq, "I2C CTRL",
            I2C_BASE + 32'h10, 32'h0, 32'h0000_0001,  // enablehost bit (RTL offset 0x10)
            pass_cnt, fail_cnt, p_sequencer.m_jtag_sqr);

        // ─── Summary ───
        `uvm_info(get_type_name(), "========== Register Reset Value Summary ==========", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  PASS: %0d  FAIL: %0d", pass_cnt, fail_cnt), UVM_LOW)
        if (fail_cnt > 0)
            `uvm_error(get_type_name(), $sformatf("Reset value test had %0d failures!", fail_cnt))
        else
            `uvm_info(get_type_name(), "All register reset values PASSED ✓", UVM_LOW)
    endtask
endclass

`endif // CHS_REG_RESET_VSEQ_SV
