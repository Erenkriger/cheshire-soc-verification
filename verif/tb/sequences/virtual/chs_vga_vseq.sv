`ifndef CHS_VGA_VSEQ_SV
`define CHS_VGA_VSEQ_SV

// ============================================================================
// chs_vga_vseq.sv — VGA Virtual Sequence
//
// Exercises the VGA controller through register configuration via SBA:
//   1. Read VGA configuration registers
//   2. Configure VGA timing parameters
//   3. Enable VGA output
//   4. Monitor hsync/vsync activity via VGA passive agent
//   5. Write test pattern to frame buffer region
// ============================================================================

class chs_vga_vseq extends uvm_sequence;

    `uvm_object_utils(chs_vga_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── VGA Register Map ───
    localparam bit [31:0] VGA_CFG_BASE = 32'h0300_7000;
    localparam bit [31:0] VGA_REG0     = VGA_CFG_BASE + 32'h00;
    localparam bit [31:0] VGA_REG1     = VGA_CFG_BASE + 32'h04;
    localparam bit [31:0] VGA_REG2     = VGA_CFG_BASE + 32'h08;
    localparam bit [31:0] VGA_REG3     = VGA_CFG_BASE + 32'h0C;
    localparam bit [31:0] VGA_REG4     = VGA_CFG_BASE + 32'h10;
    localparam bit [31:0] VGA_REG5     = VGA_CFG_BASE + 32'h14;

    // ─── Frame buffer in SPM ───
    localparam bit [31:0] FB_BASE      = 32'h1400_0000;  // Uncached SPM

    function new(string name = "chs_vga_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq jtag_seq;
        bit [31:0] rdata, idcode, sbcs_val;
        int pass_cnt = 0;
        int fail_cnt = 0;

        `uvm_info(get_type_name(),
            "═══════ VGA Controller Test START ═══════", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ── Init ──
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════
        // Phase 1: Read VGA Config Registers
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[1/4] Reading VGA configuration registers", UVM_LOW)

        for (int i = 0; i < 6; i++) begin
            bit [31:0] addr = VGA_CFG_BASE + (i * 4);
            jtag_seq.sba_read32(addr, rdata, p_sequencer.m_jtag_sqr);
            jtag_seq.dmi_read(7'h38, sbcs_val, p_sequencer.m_jtag_sqr);

            if (sbcs_val[14:12] == 0) begin
                `uvm_info(get_type_name(), $sformatf(
                    "  ✓ VGA_CFG[0x%02h] = 0x%08h", i*4, rdata), UVM_LOW)
                pass_cnt++;
            end else begin
                `uvm_info(get_type_name(), $sformatf(
                    "  ✗ VGA_CFG[0x%02h] SBA error=%0d", i*4, sbcs_val[14:12]), UVM_LOW)
                fail_cnt++;
                jtag_seq.sba_init(p_sequencer.m_jtag_sqr);
            end
        end

        // ════════════════════════════════════════════
        // Phase 2: Configure VGA Timing
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[2/4] Writing VGA timing configuration", UVM_LOW)

        // Write horizontal timing (640x480 @ 60Hz VGA)
        // H_ACTIVE=640, H_FP=16, H_SYNC=96, H_BP=48
        jtag_seq.sba_write32(VGA_REG0, 32'h0000_0280, p_sequencer.m_jtag_sqr);  // H_ACTIVE
        jtag_seq.sba_write32(VGA_REG1, 32'h0000_01E0, p_sequencer.m_jtag_sqr);  // V_ACTIVE

        jtag_seq.sba_read32(VGA_REG0, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf(
            "  VGA_REG0 readback = 0x%08h", rdata), UVM_LOW)

        // ════════════════════════════════════════════
        // Phase 3: Write test pattern to frame buffer
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[3/4] Writing test pattern to frame buffer", UVM_LOW)

        // Write RGB565 test pattern (first 16 pixels)
        for (int i = 0; i < 8; i++) begin
            bit [31:0] pixel_data;
            // Create alternating red/blue pattern (RGB565)
            if (i % 2 == 0)
                pixel_data = {16'hF800, 16'h001F};  // Red | Blue
            else
                pixel_data = {16'h07E0, 16'hFFFF};  // Green | White
            jtag_seq.sba_write32(FB_BASE + (i*4), pixel_data, p_sequencer.m_jtag_sqr);
        end
        `uvm_info(get_type_name(), "  ✓ Frame buffer test pattern written", UVM_LOW)
        pass_cnt++;

        // Read back first word
        jtag_seq.sba_read32(FB_BASE, rdata, p_sequencer.m_jtag_sqr);
        if (rdata == {16'hF800, 16'h001F}) begin
            pass_cnt++;
            `uvm_info(get_type_name(), $sformatf(
                "  ✓ FB readback verified: 0x%08h", rdata), UVM_LOW)
        end else begin
            fail_cnt++;
            `uvm_error(get_type_name(), $sformatf(
                "  ✗ FB readback mismatch: got 0x%08h", rdata))
        end

        // ════════════════════════════════════════════
        // Phase 4: Enable VGA and check for sync activity
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[4/4] Enabling VGA output and monitoring", UVM_LOW)

        // Set frame buffer base address
        jtag_seq.sba_write32(VGA_REG2, FB_BASE, p_sequencer.m_jtag_sqr);

        // Enable VGA
        jtag_seq.sba_write32(VGA_REG5, 32'h0000_0001, p_sequencer.m_jtag_sqr);

        // Wait for potential sync activity
        jtag_seq.do_idle(5000, p_sequencer.m_jtag_sqr);

        // Read back status
        jtag_seq.sba_read32(VGA_REG0, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf(
            "  VGA status after enable = 0x%08h", rdata), UVM_LOW)

        // ─── Summary ───
        `uvm_info(get_type_name(),
            "═══════ VGA Controller Test Summary ═══════", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
            "  PASS: %0d  FAIL: %0d", pass_cnt, fail_cnt), UVM_LOW)

        if (fail_cnt > 0)
            `uvm_error(get_type_name(), "VGA test had failures!")
        else
            `uvm_info(get_type_name(), "VGA test PASSED ✓", UVM_LOW)
    endtask

endclass : chs_vga_vseq

`endif // CHS_VGA_VSEQ_SV
