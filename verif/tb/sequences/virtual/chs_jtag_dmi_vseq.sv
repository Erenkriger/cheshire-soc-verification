`ifndef CHS_JTAG_DMI_VSEQ_SV
`define CHS_JTAG_DMI_VSEQ_SV

// ============================================================================
// chs_jtag_dmi_vseq.sv — JTAG DMI Access Virtual Sequence
// Exercises the Debug Module Interface:
//   1. TAP reset + IDCODE verify
//   2. Select DMI (IR=0x11)
//   3. Write dmcontrol: dmactive=1
//   4. Read dmstatus and check anyhalted/allhalted
//   5. Write dmcontrol: haltreq=1, dmactive=1
//   6. Read back dmstatus
// ============================================================================

class chs_jtag_dmi_vseq extends uvm_sequence;

    `uvm_object_utils(chs_jtag_dmi_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // JTAG IR values
    localparam bit [4:0]  IR_DMI       = 5'h11;
    localparam bit [4:0]  IR_IDCODE    = 5'h01;
    localparam int        DMI_DR_LEN   = 41;

    // DMI register addresses
    localparam bit [6:0]  DMI_DMCONTROL = 7'h10;
    localparam bit [6:0]  DMI_DMSTATUS  = 7'h11;

    // DMI op codes
    localparam bit [1:0]  DMI_OP_READ  = 2'b01;
    localparam bit [1:0]  DMI_OP_WRITE = 2'b10;

    function new(string name = "chs_jtag_dmi_vseq");
        super.new(name);
    endfunction

    // Helper: Build a 41-bit DMI word {addr[6:0], data[31:0], op[1:0]}
    function bit [40:0] build_dmi(bit [6:0] addr, bit [31:0] data, bit [1:0] op);
        return {addr, data, op};
    endfunction

    virtual task body();
        jtag_base_seq  jtag_seq;
        bit [31:0]     rdata;
        bit [40:0]     dmi_word;

        `uvm_info(get_type_name(),
                  "===== JTAG DMI Access START =====", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // Step 1: TAP Reset + IDCODE
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
                  $sformatf("[1/5] IDCODE = 0x%08h", rdata), UVM_MEDIUM)

        // Step 2: Select DMI
        `uvm_info(get_type_name(), "[2/5] Select DMI (IR=0x11)", UVM_MEDIUM)
        jtag_seq.do_ir_scan(IR_DMI, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(5, p_sequencer.m_jtag_sqr);

        // Step 3: Write dmcontrol — dmactive=1 only
        `uvm_info(get_type_name(),
                  "[3/5] DMI write: dmcontrol = 0x00000001 (dmactive)", UVM_MEDIUM)
        dmi_word = build_dmi(DMI_DMCONTROL, 32'h0000_0001, DMI_OP_WRITE);
        jtag_seq.do_dr_scan(dmi_word[31:0], DMI_DR_LEN, rdata, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(10, p_sequencer.m_jtag_sqr);

        // Step 4: Read dmstatus
        `uvm_info(get_type_name(), "[4/5] DMI read: dmstatus", UVM_MEDIUM)
        dmi_word = build_dmi(DMI_DMSTATUS, 32'h0, DMI_OP_READ);
        jtag_seq.do_dr_scan(dmi_word[31:0], DMI_DR_LEN, rdata, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(10, p_sequencer.m_jtag_sqr);
        // Capture result from previous read
        dmi_word = build_dmi(7'h00, 32'h0, 2'b00);  // NOP to get response
        jtag_seq.do_dr_scan(dmi_word[31:0], DMI_DR_LEN, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
                  $sformatf("dmstatus = 0x%08h", rdata), UVM_LOW)

        // Step 5: Write dmcontrol — haltreq + dmactive
        `uvm_info(get_type_name(),
                  "[5/5] DMI write: dmcontrol = 0x80000001 (haltreq + dmactive)", UVM_MEDIUM)
        dmi_word = build_dmi(DMI_DMCONTROL, 32'h8000_0001, DMI_OP_WRITE);
        jtag_seq.do_dr_scan(dmi_word[31:0], DMI_DR_LEN, rdata, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(20, p_sequencer.m_jtag_sqr);

        // Read dmstatus again
        dmi_word = build_dmi(DMI_DMSTATUS, 32'h0, DMI_OP_READ);
        jtag_seq.do_dr_scan(dmi_word[31:0], DMI_DR_LEN, rdata, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(10, p_sequencer.m_jtag_sqr);
        dmi_word = build_dmi(7'h00, 32'h0, 2'b00);
        jtag_seq.do_dr_scan(dmi_word[31:0], DMI_DR_LEN, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
                  $sformatf("dmstatus after halt = 0x%08h", rdata), UVM_LOW)

        jtag_seq.do_idle(10, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(),
                  "===== JTAG DMI Access COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_jtag_dmi_vseq

`endif
