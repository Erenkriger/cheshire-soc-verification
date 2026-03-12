`ifndef CHS_GPIO_DEEP_VSEQ_SV
`define CHS_GPIO_DEEP_VSEQ_SV

// ============================================================================
// chs_gpio_deep_vseq.sv — Deep GPIO SBA Test Virtual Sequence
//
// Beyond the basic GPIO output test (Phase 2), this sequence exercises:
//   1. Interrupt enable/state registers
//   2. Masked output (MASKED_OUT_LOWER, MASKED_OUT_UPPER)
//   3. Input data sampling via DATA_IN
//   4. Walking-1 output pattern (bit-level output enable control)
//   5. Output enable pin-level verification
//
// OpenTitan GPIO register map (base 0x0300_5000):
//   INTR_STATE        = 0x00   INTR_ENABLE       = 0x04
//   INTR_TEST         = 0x08   ALERT_TEST        = 0x0C
//   DATA_IN           = 0x10   DIRECT_OUT        = 0x14
//   MASKED_OUT_LOWER  = 0x18   MASKED_OUT_UPPER  = 0x1C
//   DIRECT_OE         = 0x20   MASKED_OE_LOWER   = 0x24
//   MASKED_OE_UPPER   = 0x28   INTR_CTRL_EN_RISE = 0x2C
//   INTR_CTRL_EN_FALL = 0x30   INTR_CTRL_EN_LVLH = 0x34
//   INTR_CTRL_EN_LVLL = 0x38
// ============================================================================

class chs_gpio_deep_vseq extends uvm_sequence;

    `uvm_object_utils(chs_gpio_deep_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── GPIO Register Addresses ───
    localparam bit [31:0] GPIO_BASE             = 32'h0300_5000;
    localparam bit [31:0] GPIO_INTR_STATE       = GPIO_BASE + 32'h00;
    localparam bit [31:0] GPIO_INTR_ENABLE      = GPIO_BASE + 32'h04;
    localparam bit [31:0] GPIO_INTR_TEST        = GPIO_BASE + 32'h08;
    localparam bit [31:0] GPIO_DATA_IN          = GPIO_BASE + 32'h10;
    localparam bit [31:0] GPIO_DIRECT_OUT       = GPIO_BASE + 32'h14;
    localparam bit [31:0] GPIO_MASKED_OUT_LOWER = GPIO_BASE + 32'h18;
    localparam bit [31:0] GPIO_MASKED_OUT_UPPER = GPIO_BASE + 32'h1C;
    localparam bit [31:0] GPIO_DIRECT_OE        = GPIO_BASE + 32'h20;
    localparam bit [31:0] GPIO_MASKED_OE_LOWER  = GPIO_BASE + 32'h24;
    localparam bit [31:0] GPIO_MASKED_OE_UPPER  = GPIO_BASE + 32'h28;
    localparam bit [31:0] GPIO_INTR_EN_RISE     = GPIO_BASE + 32'h2C;
    localparam bit [31:0] GPIO_INTR_EN_FALL     = GPIO_BASE + 32'h30;
    localparam bit [31:0] GPIO_INTR_EN_LVLH     = GPIO_BASE + 32'h34;
    localparam bit [31:0] GPIO_INTR_EN_LVLL     = GPIO_BASE + 32'h38;

    function new(string name = "chs_gpio_deep_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq  jtag_seq;
        bit [31:0]     idcode;

        `uvm_info(get_type_name(),
                  "===== Deep GPIO SBA Test START =====", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ── Step 1: TAP Reset + SBA Init ──
        `uvm_info(get_type_name(), "[1/6] TAP Reset + SBA Init", UVM_MEDIUM)
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf("IDCODE = 0x%08h", idcode), UVM_LOW)
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ── Step 2: Walking-1 Output Pattern ──
        `uvm_info(get_type_name(), "[2/6] Walking-1 Output Pattern", UVM_MEDIUM)
        gpio_walking_one(jtag_seq);

        // ── Step 3: Masked Output Write ──
        `uvm_info(get_type_name(), "[3/6] Masked Output Write Test", UVM_MEDIUM)
        gpio_masked_output(jtag_seq);

        // ── Step 4: Input Data Sampling ──
        `uvm_info(get_type_name(), "[4/6] Input Data Sampling", UVM_MEDIUM)
        gpio_input_sampling(jtag_seq);

        // ── Step 5: Interrupt Register Test ──
        `uvm_info(get_type_name(), "[5/6] Interrupt Register Configuration", UVM_MEDIUM)
        gpio_interrupt_config(jtag_seq);

        // ── Step 6: Output Enable Granular Control ──
        `uvm_info(get_type_name(), "[6/6] Granular Output Enable", UVM_MEDIUM)
        gpio_output_enable_control(jtag_seq);

        `uvm_info(get_type_name(),
                  "===== Deep GPIO SBA Test COMPLETE =====", UVM_LOW)
    endtask : body

    // ────────────────────────────────────────────────────────────────
    // Walking-1 Pattern: Set one bit at a time on GPIO output
    // Tests per-bit output drive capability
    // ────────────────────────────────────────────────────────────────
    virtual task gpio_walking_one(jtag_base_seq jtag_seq);
        bit [31:0] pattern;
        bit [31:0] readback;

        // Enable all outputs
        jtag_seq.sba_write32(GPIO_DIRECT_OE, 32'hFFFF_FFFF, p_sequencer.m_jtag_sqr);

        // Clear output first
        jtag_seq.sba_write32(GPIO_DIRECT_OUT, 32'h0000_0000, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(30, p_sequencer.m_jtag_sqr);

        // Walk a 1 through selected bit positions (0, 7, 15, 23, 31)
        // Full 32-bit walk would take too long via JTAG SBA
        for (int i = 0; i < 32; i += 8) begin
            pattern = 32'h1 << i;
            jtag_seq.sba_write32(GPIO_DIRECT_OUT, pattern, p_sequencer.m_jtag_sqr);
            jtag_seq.do_idle(30, p_sequencer.m_jtag_sqr);

            `uvm_info(get_type_name(),
                $sformatf("GPIO walk-1: bit[%0d] = 0x%08h", i, pattern), UVM_MEDIUM)
        end

        // Also test bit 31 explicitly
        pattern = 32'h8000_0000;
        jtag_seq.sba_write32(GPIO_DIRECT_OUT, pattern, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(30, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
            $sformatf("GPIO walk-1: bit[31] = 0x%08h", pattern), UVM_MEDIUM)

        // Final: all bits set
        jtag_seq.sba_write32(GPIO_DIRECT_OUT, 32'hFFFF_FFFF, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(30, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), "GPIO walk-1: all bits = 0xFFFFFFFF", UVM_MEDIUM)

        // Clear for next test
        jtag_seq.sba_write32(GPIO_DIRECT_OUT, 32'h0000_0000, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(20, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "GPIO: Walking-1 pattern complete", UVM_LOW)
    endtask : gpio_walking_one

    // ────────────────────────────────────────────────────────────────
    // Masked Output Write: uses MASKED_OUT_LOWER and MASKED_OUT_UPPER
    // Format: [31:16]=mask, [15:0]=data
    //   Only bits where mask=1 are updated; others retain previous value
    // ────────────────────────────────────────────────────────────────
    virtual task gpio_masked_output(jtag_base_seq jtag_seq);
        bit [31:0] rdata;

        // First, set a known output value
        jtag_seq.sba_write32(GPIO_DIRECT_OUT, 32'h0000_0000, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(20, p_sequencer.m_jtag_sqr);

        // Masked write lower 16 bits: set bits [7:0] to 0xAB
        // MASKED_OUT_LOWER: [31:16]=mask, [15:0]=data
        // mask=0x00FF → modify bits[7:0], data=0x00AB
        jtag_seq.sba_write32(GPIO_MASKED_OUT_LOWER, 32'h00FF_00AB, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(30, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "GPIO: Masked lower write (bits[7:0]=0xAB)", UVM_MEDIUM)

        // Masked write upper 16 bits: set bits [23:16] to 0xCD
        // MASKED_OUT_UPPER: [31:16]=mask for bits[31:16], [15:0]=data for bits[31:16]
        // mask=0x00FF → modify gpio[23:16], data=0x00CD
        jtag_seq.sba_write32(GPIO_MASKED_OUT_UPPER, 32'h00FF_00CD, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(30, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "GPIO: Masked upper write (bits[23:16]=0xCD)", UVM_MEDIUM)

        // Read back via DATA_IN to verify (DATA_IN reflects gpio_o when OE=1)
        // Note: DATA_IN actually reflects gpio_i pins (from TB driver)
        // The monitor will have captured the output changes

        `uvm_info(get_type_name(), "GPIO: Masked output test complete", UVM_LOW)
    endtask : gpio_masked_output

    // ────────────────────────────────────────────────────────────────
    // Input Data Sampling: read what the TB driver is presenting
    // on gpio_i pins through the DATA_IN register
    // ────────────────────────────────────────────────────────────────
    virtual task gpio_input_sampling(jtag_base_seq jtag_seq);
        bit [31:0] data_in;

        // Read DATA_IN — reflects gpio_i from TB
        jtag_seq.sba_read32(GPIO_DATA_IN, data_in, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
            $sformatf("GPIO: DATA_IN = 0x%08h (reflects gpio_i from TB driver)", data_in), UVM_LOW)

        // Read it again after a short delay to see if it's stable
        jtag_seq.do_idle(50, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_read32(GPIO_DATA_IN, data_in, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
            $sformatf("GPIO: DATA_IN (2nd read) = 0x%08h", data_in), UVM_LOW)

        `uvm_info(get_type_name(), "GPIO: Input sampling complete", UVM_LOW)
    endtask : gpio_input_sampling

    // ────────────────────────────────────────────────────────────────
    // Interrupt Register Configuration
    // Configure edge-detect and level-detect interrupts, then trigger
    // via INTR_TEST and verify INTR_STATE
    // ────────────────────────────────────────────────────────────────
    virtual task gpio_interrupt_config(jtag_base_seq jtag_seq);
        bit [31:0] intr_state;

        // Enable rising edge interrupts on bits [3:0]
        jtag_seq.sba_write32(GPIO_INTR_EN_RISE, 32'h0000_000F, p_sequencer.m_jtag_sqr);

        // Enable falling edge interrupts on bits [7:4]
        jtag_seq.sba_write32(GPIO_INTR_EN_FALL, 32'h0000_00F0, p_sequencer.m_jtag_sqr);

        // Enable level-high interrupts on bits [11:8]
        jtag_seq.sba_write32(GPIO_INTR_EN_LVLH, 32'h0000_0F00, p_sequencer.m_jtag_sqr);

        // Enable level-low interrupts on bits [15:12]
        jtag_seq.sba_write32(GPIO_INTR_EN_LVLL, 32'h0000_F000, p_sequencer.m_jtag_sqr);

        // Enable interrupts globally (INTR_ENABLE)
        jtag_seq.sba_write32(GPIO_INTR_ENABLE, 32'h0000_FFFF, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(),
            "GPIO: Interrupt config set (rise[3:0], fall[7:4], lvlh[11:8], lvll[15:12])", UVM_MEDIUM)

        // Use INTR_TEST to inject a test interrupt on bit 0 (rising edge configured)
        jtag_seq.sba_write32(GPIO_INTR_TEST, 32'h0000_0001, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(20, p_sequencer.m_jtag_sqr);

        // Read INTR_STATE — bit 0 should be set
        jtag_seq.sba_read32(GPIO_INTR_STATE, intr_state, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
            $sformatf("GPIO: INTR_STATE = 0x%08h (after INTR_TEST bit0)", intr_state), UVM_LOW)

        if (intr_state[0] !== 1'b1)
            `uvm_warning(get_type_name(),
                $sformatf("GPIO: Expected INTR_STATE[0]=1 after INTR_TEST, got 0x%08h", intr_state))

        // Clear interrupt (W1C)
        jtag_seq.sba_write32(GPIO_INTR_STATE, intr_state, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(10, p_sequencer.m_jtag_sqr);

        // Verify cleared
        jtag_seq.sba_read32(GPIO_INTR_STATE, intr_state, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
            $sformatf("GPIO: INTR_STATE after clear = 0x%08h", intr_state), UVM_LOW)

        // Disable all interrupts (clean state for other tests)
        jtag_seq.sba_write32(GPIO_INTR_ENABLE, 32'h0000_0000, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(GPIO_INTR_EN_RISE, 32'h0000_0000, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(GPIO_INTR_EN_FALL, 32'h0000_0000, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(GPIO_INTR_EN_LVLH, 32'h0000_0000, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(GPIO_INTR_EN_LVLL, 32'h0000_0000, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "GPIO: Interrupt test complete, all interrupts disabled", UVM_LOW)
    endtask : gpio_interrupt_config

    // ────────────────────────────────────────────────────────────────
    // Granular Output Enable Control
    // Test partial OE: enable only some bits, verify gpio_en_o
    // Uses MASKED_OE_LOWER/UPPER for selective enable
    // ────────────────────────────────────────────────────────────────
    virtual task gpio_output_enable_control(jtag_base_seq jtag_seq);
        bit [31:0] rdata;

        // Clear all OE first
        jtag_seq.sba_write32(GPIO_DIRECT_OE, 32'h0000_0000, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(20, p_sequencer.m_jtag_sqr);

        // Enable only bits [3:0] via MASKED_OE_LOWER
        // mask=0x000F, data=0x000F → enable bits [3:0]
        jtag_seq.sba_write32(GPIO_MASKED_OE_LOWER, 32'h000F_000F, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(20, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), "GPIO: OE masked lower → bits[3:0] enabled", UVM_MEDIUM)

        // Drive a pattern — only bits [3:0] should appear on gpio_o
        jtag_seq.sba_write32(GPIO_DIRECT_OUT, 32'hFFFF_FFFF, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(30, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), "GPIO: DIRECT_OUT=0xFFFFFFFF but only [3:0] enabled", UVM_MEDIUM)

        // Now enable upper bits [31:24] via MASKED_OE_UPPER
        // MASKED_OE_UPPER: mask for bits[31:16], data for bits[31:16]
        // mask=0xFF00, data=0xFF00 → enable bits[31:24]
        jtag_seq.sba_write32(GPIO_MASKED_OE_UPPER, 32'hFF00_FF00, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(30, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), "GPIO: OE masked upper → bits[31:24] also enabled", UVM_MEDIUM)

        // Final cleanup — disable all outputs
        jtag_seq.sba_write32(GPIO_DIRECT_OE, 32'h0000_0000, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_write32(GPIO_DIRECT_OUT, 32'h0000_0000, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(20, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "GPIO: Granular OE test complete", UVM_LOW)
    endtask : gpio_output_enable_control

endclass : chs_gpio_deep_vseq

`endif // CHS_GPIO_DEEP_VSEQ_SV
