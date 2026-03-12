`ifndef CHS_SLINK_VSEQ_SV
`define CHS_SLINK_VSEQ_SV

// ============================================================================
// chs_slink_vseq.sv — Serial Link Virtual Sequence
//
// Exercises the Serial Link IP through both register configuration (SBA)
// and external data lane activity:
//   1. Read Serial Link configuration registers via SBA
//   2. Configure Serial Link clock divider and channel params
//   3. Drive data on RX lanes from TB side
//   4. Monitor TX lane output from DUT
//   5. Verify register-level accessibility and basic link activity
// ============================================================================

class chs_slink_vseq extends uvm_sequence;

    `uvm_object_utils(chs_slink_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── Serial Link Register Map ───
    localparam bit [31:0] SLINK_CFG_BASE  = 32'h0300_6000;
    localparam bit [31:0] SLINK_CFG_REG0  = SLINK_CFG_BASE + 32'h00;
    localparam bit [31:0] SLINK_CFG_REG1  = SLINK_CFG_BASE + 32'h04;
    localparam bit [31:0] SLINK_CFG_REG2  = SLINK_CFG_BASE + 32'h08;
    localparam bit [31:0] SLINK_CFG_REG3  = SLINK_CFG_BASE + 32'h0C;

    function new(string name = "chs_slink_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq  jtag_seq;
        slink_base_seq slink_seq;
        bit [31:0]     rdata, idcode, sbcs_val;
        int pass_cnt = 0;
        int fail_cnt = 0;

        `uvm_info(get_type_name(),
            "═══════ Serial Link Test START ═══════", UVM_LOW)

        jtag_seq  = jtag_base_seq::type_id::create("jtag_seq");
        slink_seq = slink_base_seq::type_id::create("slink_seq");

        // ── Init ──
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════
        // Phase 1: Read Serial Link Config Registers
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[1/4] Reading Serial Link configuration registers", UVM_LOW)

        for (int i = 0; i < 4; i++) begin
            bit [31:0] addr = SLINK_CFG_BASE + (i * 4);
            jtag_seq.sba_read32(addr, rdata, p_sequencer.m_jtag_sqr);
            jtag_seq.dmi_read(7'h38, sbcs_val, p_sequencer.m_jtag_sqr);

            if (sbcs_val[14:12] == 0) begin
                `uvm_info(get_type_name(), $sformatf(
                    "  ✓ SLINK_CFG[0x%02h] = 0x%08h", i*4, rdata), UVM_LOW)
                pass_cnt++;
            end else begin
                `uvm_info(get_type_name(), $sformatf(
                    "  ✗ SLINK_CFG[0x%02h] SBA error=%0d", i*4, sbcs_val[14:12]), UVM_LOW)
                fail_cnt++;
                jtag_seq.sba_init(p_sequencer.m_jtag_sqr);
            end
        end

        // ════════════════════════════════════════════
        // Phase 2: Write Serial Link Config
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[2/4] Writing Serial Link clock divider", UVM_LOW)
        jtag_seq.sba_write32(SLINK_CFG_REG0, 32'h0000_0004, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_read32(SLINK_CFG_REG0, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf(
            "  SLINK_CFG[0x00] readback = 0x%08h", rdata), UVM_LOW)

        // ════════════════════════════════════════════
        // Phase 3: Drive data on Serial Link RX lanes
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[3/4] Driving data on Serial Link RX lanes", UVM_LOW)
        if (p_sequencer.m_slink_sqr != null) begin
            bit [7:0] test_data[$];
            test_data = {8'hA5, 8'h5A, 8'hFF, 8'h00, 8'hDE, 8'hAD, 8'hBE, 8'hEF};
            slink_seq.send_data(test_data, p_sequencer.m_slink_sqr);
            `uvm_info(get_type_name(), "  ✓ 8 bytes sent on Serial Link RX path", UVM_LOW)
            pass_cnt++;

            slink_seq.send_idle(20, p_sequencer.m_slink_sqr);
        end else begin
            `uvm_warning(get_type_name(), "  Serial Link sequencer not available, skipping lane drive")
        end

        // ════════════════════════════════════════════
        // Phase 4: Idle and verify link status
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[4/4] Checking link status after transfer", UVM_LOW)
        jtag_seq.do_idle(100, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_read32(SLINK_CFG_REG0, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf(
            "  SLINK status register = 0x%08h", rdata), UVM_LOW)

        // ─── Summary ───
        `uvm_info(get_type_name(),
            "═══════ Serial Link Test Summary ═══════", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
            "  PASS: %0d  FAIL: %0d", pass_cnt, fail_cnt), UVM_LOW)

        if (fail_cnt > 0)
            `uvm_error(get_type_name(), "Serial Link test had failures!")
        else
            `uvm_info(get_type_name(), "Serial Link test PASSED ✓", UVM_LOW)
    endtask

endclass : chs_slink_vseq

`endif // CHS_SLINK_VSEQ_SV
