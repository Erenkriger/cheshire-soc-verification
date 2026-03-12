`ifndef CHS_SMOKE_VSEQ_SV
`define CHS_SMOKE_VSEQ_SV

// ============================================================================
// chs_smoke_vseq.sv — Cheshire Smoke Virtual Sequence
// Basic system-level smoke test:
//   1. JTAG reset + IDCODE check
//   2. GPIO: drive all zeros, then all ones
//   3. Wait some idle cycles
// ============================================================================

class chs_smoke_vseq extends uvm_sequence;

    `uvm_object_utils(chs_smoke_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // JTAG constants
    localparam bit [4:0] IR_IDCODE = 5'h01;

    function new(string name = "chs_smoke_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq  jtag_seq;
        gpio_base_seq  gpio_seq;
        bit [31:0]     rdata;

        `uvm_info(get_type_name(), "===== Smoke Virtual Sequence START =====", UVM_LOW)

        // ----------------------------------------------------------------
        // JTAG: Reset + IDCODE
        // ----------------------------------------------------------------
        `uvm_info(get_type_name(), "[JTAG] TAP reset + IDCODE read", UVM_MEDIUM)
        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
                  $sformatf("[JTAG] IDCODE = 0x%08h", rdata), UVM_MEDIUM)
        jtag_seq.do_idle(5, p_sequencer.m_jtag_sqr);

        // ----------------------------------------------------------------
        // GPIO: Drive all zeros, then all ones
        // ----------------------------------------------------------------
        `uvm_info(get_type_name(), "[GPIO] Drive all zeros", UVM_MEDIUM)
        gpio_seq = gpio_base_seq::type_id::create("gpio_seq");

        gpio_seq.drive_all(32'h0000_0000, p_sequencer.m_gpio_sqr);

        `uvm_info(get_type_name(), "[GPIO] Drive all ones", UVM_MEDIUM)
        gpio_seq.drive_all(32'hFFFF_FFFF, p_sequencer.m_gpio_sqr);

        // ----------------------------------------------------------------
        // Idle wait
        // ----------------------------------------------------------------
        `uvm_info(get_type_name(), "[IDLE] Waiting 20 cycles", UVM_MEDIUM)
        jtag_seq.do_idle(20, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "===== Smoke Virtual Sequence COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_smoke_vseq

`endif // CHS_SMOKE_VSEQ_SV
