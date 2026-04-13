// ============================================================================
// chs_cov_gpio_exhaustive_vseq.sv — GPIO Exhaustive Coverage Booster
//
// Targets uncovered bins:
//   - OE patterns: all_input(0), all_output(FF..FF), lower_half, upper_half,
//                  lower_byte, byte_pattern(00FF00FF), mixed
//   - Data patterns: all_zero, all_one, checkerboard(55/AA),
//                    walking_one (8 bins), others
//   - Transitions: no_change, single_bit, multi_bit
//   - Cross: en_x_data (OE pattern × data pattern)
// ============================================================================

`ifndef CHS_COV_GPIO_EXHAUSTIVE_VSEQ_SV
`define CHS_COV_GPIO_EXHAUSTIVE_VSEQ_SV

class chs_cov_gpio_exhaustive_vseq extends uvm_sequence;

    `uvm_object_utils(chs_cov_gpio_exhaustive_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_cov_gpio_exhaustive_vseq");
        super.new(name);
    endfunction

    // ─── JTAG helpers ───
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

    task dmi_write(bit [6:0] addr, bit [31:0] data);
        bit [63:0] dmi_word, rdata;
        dmi_word = {23'b0, addr, data, 2'b10};
        jtag_dr_scan(41, dmi_word, rdata);
        do_idle(10);
    endtask

    task sba_write32(bit [31:0] addr, bit [31:0] data);
        dmi_write(7'h39, addr);
        dmi_write(7'h3C, data);
        do_idle(20);
    endtask

    // GPIO register addresses (OpenTitan GPIO)
    localparam bit [31:0] GPIO_BASE    = 32'h0300_5000;
    localparam bit [31:0] GPIO_OUT     = 32'h0300_5014;  // DIRECT_OUT (offset 0x14)
    localparam bit [31:0] GPIO_OE      = 32'h0300_5020;  // DIRECT_OE  (offset 0x20)

    task gpio_set_oe(bit [31:0] oe);
        sba_write32(GPIO_OE, oe);
        do_idle(5);
    endtask

    task gpio_set_out(bit [31:0] data);
        sba_write32(GPIO_OUT, data);
        do_idle(5);
    endtask

    virtual task body();
        int i;
        `uvm_info(get_type_name(), "===== GPIO Exhaustive Coverage START =====", UVM_LOW)

        m_sequencer = p_sequencer.m_jtag_sqr;

        // ─── Setup: TAP Reset + SBA Init ───
        jtag_reset();
        do_idle(5);
        jtag_ir_scan(5'h11);
        dmi_write(7'h10, 32'h0000_0001);
        do_idle(5);
        dmi_write(7'h38, 32'h0004_0000);
        do_idle(5);

        // ═══════════════════════════════════════════════════════
        // Phase 1: OE Pattern Coverage (7 bins)
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[1/5] OE Pattern Sweep", UVM_LOW)

        // all_input (0x00000000)
        gpio_set_oe(32'h0000_0000);
        gpio_set_out(32'h0000_0000);

        // all_output (0xFFFFFFFF)
        gpio_set_oe(32'hFFFF_FFFF);
        gpio_set_out(32'h1234_5678);

        // lower_half (0x0000FFFF)
        gpio_set_oe(32'h0000_FFFF);
        gpio_set_out(32'hAAAA_5555);

        // upper_half (0xFFFF0000)
        gpio_set_oe(32'hFFFF_0000);
        gpio_set_out(32'hDEAD_0000);

        // lower_byte (0x000000FF)
        gpio_set_oe(32'h0000_00FF);
        gpio_set_out(32'h0000_00AB);

        // byte_pattern (0x00FF00FF)
        gpio_set_oe(32'h00FF_00FF);
        gpio_set_out(32'h00CD_00EF);

        // mixed (anything else — 0xFF00FF00)
        gpio_set_oe(32'hFF00_FF00);
        gpio_set_out(32'hAB00_CD00);

        // ═══════════════════════════════════════════════════════
        // Phase 2: Data Pattern Coverage (all bins)
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[2/5] Data Pattern Sweep", UVM_LOW)

        // Ensure all output for visibility
        gpio_set_oe(32'hFFFF_FFFF);

        // all_zero
        gpio_set_out(32'h0000_0000);

        // all_one
        gpio_set_out(32'hFFFF_FFFF);

        // checkerboard patterns
        gpio_set_out(32'h5555_5555);
        gpio_set_out(32'hAAAA_AAAA);

        // walking_one — all 8 defined bins
        gpio_set_out(32'h0000_0001);
        gpio_set_out(32'h0000_0002);
        gpio_set_out(32'h0000_0004);
        gpio_set_out(32'h0000_0008);
        gpio_set_out(32'h0000_0010);
        gpio_set_out(32'h0000_0020);
        gpio_set_out(32'h0000_0040);
        gpio_set_out(32'h0000_0080);

        // others — random patterns
        gpio_set_out(32'hCAFE_BABE);
        gpio_set_out(32'hDEAD_BEEF);
        gpio_set_out(32'h1357_9BDF);

        // ═══════════════════════════════════════════════════════
        // Phase 3: Transition Coverage (no_change, single_bit, multi_bit)
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[3/5] Transition Coverage", UVM_LOW)

        // Start from known value
        gpio_set_out(32'h0000_0000);

        // no_change (write same value)
        gpio_set_out(32'h0000_0000);

        // single_bit transition (0→1 on bit 0)
        gpio_set_out(32'h0000_0001);

        // single_bit transition (bit 1)
        gpio_set_out(32'h0000_0003);  // multi-bit from 0001→0003
        gpio_set_out(32'h0000_0001);  // single-bit back (bit 1 only)

        // multi_bit transition
        gpio_set_out(32'hFFFF_FFFF);  // massive multi-bit
        gpio_set_out(32'h0000_0000);  // massive multi-bit back
        gpio_set_out(32'hABCD_EF01);  // multi-bit

        // ═══════════════════════════════════════════════════════
        // Phase 4: Cross Coverage (OE × Data) — systematic combos
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[4/5] OE × Data Cross Coverage", UVM_LOW)

        // all_output × all patterns
        gpio_set_oe(32'hFFFF_FFFF);
        gpio_set_out(32'h0000_0000);
        gpio_set_out(32'hFFFF_FFFF);
        gpio_set_out(32'h5555_5555);
        gpio_set_out(32'h0000_0001);

        // lower_half × patterns
        gpio_set_oe(32'h0000_FFFF);
        gpio_set_out(32'h0000_0000);
        gpio_set_out(32'hFFFF_FFFF);
        gpio_set_out(32'hAAAA_AAAA);

        // upper_half × patterns
        gpio_set_oe(32'hFFFF_0000);
        gpio_set_out(32'h0000_0000);
        gpio_set_out(32'hFFFF_FFFF);
        gpio_set_out(32'h5555_5555);

        // lower_byte × patterns
        gpio_set_oe(32'h0000_00FF);
        gpio_set_out(32'h0000_0000);
        gpio_set_out(32'hFFFF_FFFF);
        gpio_set_out(32'h0000_0001);

        // byte_pattern × patterns
        gpio_set_oe(32'h00FF_00FF);
        gpio_set_out(32'h0000_0000);
        gpio_set_out(32'hFFFF_FFFF);

        // all_input × patterns (gated — output should be 0)
        gpio_set_oe(32'h0000_0000);
        gpio_set_out(32'hFFFF_FFFF);
        gpio_set_out(32'h0000_0000);

        // ═══════════════════════════════════════════════════════
        // Phase 5: Walking ones across higher bits
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[5/5] Upper Walking Ones", UVM_LOW)

        gpio_set_oe(32'hFFFF_FFFF);
        for (i = 8; i < 32; i = i + 4) begin
            gpio_set_out(32'h1 << i);
        end

        // Final state
        gpio_set_out(32'h0000_0000);

        `uvm_info(get_type_name(), "===== GPIO Exhaustive Coverage COMPLETE =====", UVM_LOW)
    endtask

endclass : chs_cov_gpio_exhaustive_vseq

`endif // CHS_COV_GPIO_EXHAUSTIVE_VSEQ_SV
