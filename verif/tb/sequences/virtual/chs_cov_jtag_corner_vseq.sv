// ============================================================================
// chs_cov_jtag_corner_vseq.sv — JTAG Corner-Case Coverage Booster
//
// Targets uncovered bins:
//   - All IR values: IDCODE(01), DTMCS(10), DMI(11), BYPASS(1F), others
//   - DR lengths: zero, short(1-8), medium(9-32), long(33-41), very_long(42-64)
//   - DMI ops: NOP(00), READ(01), WRITE(10), RSV(11)
//   - DMI addrs: SBCS(38), SBADDR0(39), SBDATA0(3C), DMCONTROL(10), DMSTATUS(11)
//   - Cross: ir_to_idcode, ir_to_dmi, ir_to_dtmcs, dr_with_idcode, dr_with_dmi
// ============================================================================

`ifndef CHS_COV_JTAG_CORNER_VSEQ_SV
`define CHS_COV_JTAG_CORNER_VSEQ_SV

class chs_cov_jtag_corner_vseq extends uvm_sequence;

    `uvm_object_utils(chs_cov_jtag_corner_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_cov_jtag_corner_vseq");
        super.new(name);
    endfunction

    // ─── Low-level JTAG helpers ───
    task do_idle(int unsigned cycles);
        jtag_transaction tr;
        tr = jtag_transaction::type_id::create("idle_tr");
        tr.op = jtag_transaction::JTAG_IDLE;
        tr.idle_cycles = cycles;
        tr.dr_length = 0;
        start_item(tr);
        finish_item(tr);
    endtask

    task jtag_ir_scan(bit [4:0] ir);
        jtag_transaction tr;
        tr = jtag_transaction::type_id::create("ir_tr");
        tr.op = jtag_transaction::JTAG_IR_SCAN;
        tr.ir_value = ir;
        tr.dr_length = 0;
        start_item(tr);
        finish_item(tr);
    endtask

    task jtag_dr_scan(int unsigned length, bit [63:0] data, output bit [63:0] rdata);
        jtag_transaction tr;
        tr = jtag_transaction::type_id::create("dr_tr");
        tr.op = jtag_transaction::JTAG_DR_SCAN;
        tr.dr_value = data;
        tr.dr_length = length;
        start_item(tr);
        finish_item(tr);
        rdata = tr.dr_rdata;
    endtask

    task jtag_reset();
        jtag_transaction tr;
        tr = jtag_transaction::type_id::create("rst_tr");
        tr.op = jtag_transaction::JTAG_RESET;
        tr.dr_length = 0;
        start_item(tr);
        finish_item(tr);
    endtask

    // DMI helpers
    task dmi_write(bit [6:0] addr, bit [31:0] data);
        bit [63:0] dmi_word, rdata;
        dmi_word = {23'b0, addr, data, 2'b10};
        jtag_dr_scan(41, dmi_word, rdata);
        do_idle(10);
    endtask

    task dmi_read(bit [6:0] addr, output bit [31:0] data);
        bit [63:0] dmi_word, rdata;
        dmi_word = {23'b0, addr, 32'b0, 2'b01};
        jtag_dr_scan(41, dmi_word, rdata);
        do_idle(10);
        dmi_word = {23'b0, 7'b0, 32'b0, 2'b00};
        jtag_dr_scan(41, dmi_word, rdata);
        data = rdata[33:2];
    endtask

    task dmi_nop();
        bit [63:0] dmi_word, rdata;
        dmi_word = {23'b0, 7'b0, 32'b0, 2'b00};  // op=NOP
        jtag_dr_scan(41, dmi_word, rdata);
        do_idle(5);
    endtask

    virtual task body();
        bit [63:0] rdata;
        bit [31:0] rd32;

        `uvm_info(get_type_name(), "===== JTAG Corner-Case Coverage START =====", UVM_LOW)

        m_sequencer = p_sequencer.m_jtag_sqr;

        // ─── Phase 1: TAP Reset (covers JTAG_RESET op) ───
        `uvm_info(get_type_name(), "[1/7] TAP Reset", UVM_LOW)
        jtag_reset();
        do_idle(5);

        // ─── Phase 2: All IR values with DR scans ───
        `uvm_info(get_type_name(), "[2/7] IR Sweep — all IR values", UVM_LOW)

        // IDCODE (0x01) — covers ir_to_idcode, dr_with_idcode
        jtag_ir_scan(5'h01);
        jtag_dr_scan(33, 64'h0, rdata);  // medium DR (33)
        `uvm_info(get_type_name(), $sformatf("  IDCODE = 0x%08h", rdata[31:0]), UVM_LOW)

        // DTMCS (0x10) — covers ir_to_dtmcs
        jtag_ir_scan(5'h10);
        jtag_dr_scan(32, 64'h0, rdata);  // medium DR (32)
        `uvm_info(get_type_name(), $sformatf("  DTMCS  = 0x%08h", rdata[31:0]), UVM_LOW)

        // DMI (0x11) — covers ir_to_dmi, dr_with_dmi
        jtag_ir_scan(5'h11);
        jtag_dr_scan(41, {23'b0, 7'h11, 32'b0, 2'b01}, rdata);  // long DR (41)
        do_idle(10);

        // BYPASS (0x1F) — covers bypass bin
        jtag_ir_scan(5'h1f);
        jtag_dr_scan(1, 64'h0, rdata);  // short DR (1)
        do_idle(5);

        // "Others" IR values — covers 'others' default bin
        jtag_ir_scan(5'h02);
        jtag_dr_scan(8, 64'hAB, rdata);  // short DR (8)
        do_idle(3);

        jtag_ir_scan(5'h05);
        jtag_dr_scan(16, 64'hDEAD, rdata);  // medium-low DR
        do_idle(3);

        jtag_ir_scan(5'h0A);
        jtag_dr_scan(4, 64'hF, rdata);  // short DR (4)
        do_idle(3);

        // ─── Phase 3: DR Length Coverage Sweep ───
        `uvm_info(get_type_name(), "[3/7] DR Length Sweep", UVM_LOW)

        // Back to IDCODE for safe DR scans
        jtag_ir_scan(5'h01);

        // short_dr: 1-8
        jtag_dr_scan(1, 64'h1, rdata);
        jtag_dr_scan(4, 64'hA, rdata);
        jtag_dr_scan(8, 64'hFF, rdata);

        // medium_dr: 9-32
        jtag_dr_scan(16, 64'hBEEF, rdata);
        jtag_dr_scan(24, 64'hCAFE00, rdata);
        jtag_dr_scan(32, 64'hDEADBEEF, rdata);

        // long_dr: 33-41 (via DMI)
        jtag_ir_scan(5'h11);
        jtag_dr_scan(33, 64'h1_FACE_CAFE, rdata);
        do_idle(5);
        jtag_dr_scan(41, {23'b0, 7'h0, 32'h0, 2'b00}, rdata);
        do_idle(5);

        // very_long_dr: 42-64
        jtag_ir_scan(5'h01);  // safe IR
        jtag_dr_scan(48, 64'hFACE_CAFE_BABE, rdata);
        jtag_dr_scan(56, 64'h00FF_00FF_00FF_00, rdata);
        jtag_dr_scan(64, 64'hFFFF_FFFF_FFFF_FFFF, rdata);
        do_idle(5);

        // ─── Phase 4: DMI Operation Types ───
        `uvm_info(get_type_name(), "[4/7] DMI Op Coverage — NOP, READ, WRITE, RSV", UVM_LOW)

        jtag_ir_scan(5'h11);

        // DMI NOP (op=00) — hit nop bin
        dmi_nop();
        dmi_nop();

        // DMI READ (op=01) — read dmstatus
        dmi_read(7'h11, rd32);
        `uvm_info(get_type_name(), $sformatf("  DMSTATUS = 0x%08h", rd32), UVM_LOW)

        // DMI WRITE (op=10) — write dmcontrol (dmactive)
        dmi_write(7'h10, 32'h0000_0001);

        // DMI RSV (op=11) — reserved, for coverage only
        begin
            bit [63:0] rsv_word, rsv_rdata;
            rsv_word = {23'b0, 7'h0, 32'h0, 2'b11};
            jtag_dr_scan(41, rsv_word, rsv_rdata);
            do_idle(10);
        end

        // ─── Phase 5: DMI Address Coverage ───
        `uvm_info(get_type_name(), "[5/7] DMI Address Coverage — SBCS, SBADDR0, SBDATA0", UVM_LOW)

        // DMCONTROL (0x10) — already hit above
        // DMSTATUS (0x11) — already hit above

        // SBCS (0x38) — enable SBA
        dmi_write(7'h38, 32'h0004_0000);
        do_idle(5);
        dmi_read(7'h38, rd32);
        `uvm_info(get_type_name(), $sformatf("  SBCS     = 0x%08h", rd32), UVM_LOW)

        // SBADDR0 (0x39)
        dmi_write(7'h39, 32'h0300_5014);
        do_idle(5);
        dmi_read(7'h39, rd32);
        `uvm_info(get_type_name(), $sformatf("  SBADDR0  = 0x%08h", rd32), UVM_LOW)

        // SBDATA0 (0x3C)
        dmi_read(7'h3C, rd32);
        `uvm_info(get_type_name(), $sformatf("  SBDATA0  = 0x%08h", rd32), UVM_LOW)

        // Other DMI addresses for coverage
        dmi_read(7'h04, rd32);  // HARTINFO
        do_idle(3);
        dmi_read(7'h16, rd32);  // ABSTRACTCS
        do_idle(3);

        // ─── Phase 6: Idle cycles with different counts ───
        `uvm_info(get_type_name(), "[6/7] Idle Cycle Variations", UVM_LOW)
        do_idle(1);
        do_idle(5);
        do_idle(20);
        do_idle(50);

        // ─── Phase 7: Multiple resets for reset bin ───
        `uvm_info(get_type_name(), "[7/7] Multiple TAP Resets", UVM_LOW)
        jtag_reset();
        do_idle(5);
        jtag_reset();
        do_idle(5);

        `uvm_info(get_type_name(), "===== JTAG Corner-Case Coverage COMPLETE =====", UVM_LOW)
    endtask

endclass : chs_cov_jtag_corner_vseq

`endif // CHS_COV_JTAG_CORNER_VSEQ_SV
