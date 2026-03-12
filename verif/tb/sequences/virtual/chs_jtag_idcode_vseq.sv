`ifndef CHS_JTAG_IDCODE_VSEQ_SV
`define CHS_JTAG_IDCODE_VSEQ_SV

// ============================================================================
// chs_jtag_idcode_vseq.sv — JTAG IDCODE Verify Virtual Sequence
// Reads IDCODE and checks that LSB=1 (JTAG spec mandatory).
// Reads IDCODE multiple times to verify deterministic behavior.
// ============================================================================

class chs_jtag_idcode_vseq extends uvm_sequence;

    `uvm_object_utils(chs_jtag_idcode_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    localparam bit [4:0] IR_IDCODE = 5'h01;

    function new(string name = "chs_jtag_idcode_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq  jtag_seq;
        bit [31:0]     rdata, rdata2;

        `uvm_info(get_type_name(),
                  "===== JTAG IDCODE Verify START =====", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // Step 1: TAP Reset
        `uvm_info(get_type_name(), "[1/4] TAP Reset", UVM_MEDIUM)
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);

        // Step 2: First IDCODE Read
        `uvm_info(get_type_name(), "[2/4] First IDCODE read", UVM_MEDIUM)
        jtag_seq.do_ir_scan(IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, rdata, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(),
                  $sformatf("IDCODE = 0x%08h", rdata), UVM_LOW)

        // Check: JTAG spec requires LSB=1
        if (rdata[0] !== 1'b1)
            `uvm_error(get_type_name(),
                       $sformatf("IDCODE LSB must be 1, got 0x%08h", rdata))
        else
            `uvm_info(get_type_name(), "IDCODE LSB=1 check PASSED", UVM_MEDIUM)

        // Step 3: Second IDCODE Read — must be identical
        `uvm_info(get_type_name(), "[3/4] Second IDCODE read (consistency)", UVM_MEDIUM)
        jtag_seq.do_ir_scan(IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, rdata2, p_sequencer.m_jtag_sqr);

        if (rdata !== rdata2)
            `uvm_error(get_type_name(),
                       $sformatf("IDCODE mismatch: 1st=0x%08h 2nd=0x%08h", rdata, rdata2))
        else
            `uvm_info(get_type_name(), "IDCODE consistency check PASSED", UVM_MEDIUM)

        // Step 4: Idle
        `uvm_info(get_type_name(), "[4/4] Idle", UVM_MEDIUM)
        jtag_seq.do_idle(10, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(),
                  "===== JTAG IDCODE Verify COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_jtag_idcode_vseq

`endif
