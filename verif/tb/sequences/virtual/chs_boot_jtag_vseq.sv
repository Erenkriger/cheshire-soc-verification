`ifndef CHS_BOOT_JTAG_VSEQ_SV
`define CHS_BOOT_JTAG_VSEQ_SV

// ============================================================================
// chs_boot_jtag_vseq.sv — Cheshire JTAG Boot Virtual Sequence
// System-level virtual sequence that:
//   1. Resets the JTAG TAP
//   2. Reads and verifies the IDCODE
//   3. Accesses the RISC-V Debug Module via DMI
//   4. Writes DMI register to halt the core and reads status
// ============================================================================

class chs_boot_jtag_vseq extends uvm_sequence;

    `uvm_object_utils(chs_boot_jtag_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ----- JTAG / DMI constants -----
    localparam bit [4:0]  IR_DMI       = 5'h11;
    localparam bit [4:0]  IR_IDCODE    = 5'h01;
    localparam int        DMI_DR_LEN   = 41;

    // Expected IDCODE for RISC-V Debug (version 0.13)
    localparam bit [31:0] EXP_IDCODE   = 32'h00000001;

    // DMI register addresses
    localparam bit [6:0]  DMI_DMCONTROL = 7'h10;
    localparam bit [6:0]  DMI_DMSTATUS  = 7'h11;

    // DMI op codes
    localparam bit [1:0]  DMI_OP_NOP   = 2'b00;
    localparam bit [1:0]  DMI_OP_READ  = 2'b01;
    localparam bit [1:0]  DMI_OP_WRITE = 2'b10;

    function new(string name = "chs_boot_jtag_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq  jtag_seq;
        bit [31:0]     rdata;
        bit [40:0]     dmi_word;

        `uvm_info(get_type_name(), "===== JTAG Boot Virtual Sequence START =====", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ---- Step 1: Reset TAP ----
        `uvm_info(get_type_name(), "[1/4] Resetting JTAG TAP", UVM_MEDIUM)
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);

        // ---- Step 2: Read & Verify IDCODE ----
        `uvm_info(get_type_name(), "[2/4] Reading IDCODE", UVM_MEDIUM)
        jtag_seq.do_ir_scan(IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, rdata, p_sequencer.m_jtag_sqr);

        if (rdata[0] !== 1'b1)
            `uvm_warning(get_type_name(),
                         $sformatf("IDCODE LSB not 1: got 0x%08h", rdata))
        else
            `uvm_info(get_type_name(),
                      $sformatf("IDCODE read OK: 0x%08h", rdata), UVM_MEDIUM)

        // ---- Step 3: Select DMI ----
        `uvm_info(get_type_name(), "[3/4] Selecting DMI (IR=0x11)", UVM_MEDIUM)
        jtag_seq.do_ir_scan(IR_DMI, p_sequencer.m_jtag_sqr);

        // ---- Step 4: DMI Write — Halt request via dmcontrol ----
        `uvm_info(get_type_name(), "[4/4] DMI write: halt request (dmcontrol)", UVM_MEDIUM)

        // dmcontrol: haltreq=1 (bit 31), dmactive=1 (bit 0)
        // DMI format: {addr[6:0], data[31:0], op[1:0]} = 41 bits
        dmi_word = {DMI_DMCONTROL, 32'h8000_0001, DMI_OP_WRITE};
        jtag_seq.do_dr_scan(dmi_word[31:0], DMI_DR_LEN, rdata, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(10, p_sequencer.m_jtag_sqr);

        // DMI Read dmstatus
        dmi_word = {DMI_DMSTATUS, 32'h0000_0000, DMI_OP_READ};
        jtag_seq.do_dr_scan(dmi_word[31:0], DMI_DR_LEN, rdata, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(10, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(),
                  $sformatf("dmstatus read-back: 0x%08h", rdata), UVM_MEDIUM)

        `uvm_info(get_type_name(),
                  "===== JTAG Boot Virtual Sequence COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_boot_jtag_vseq

`endif // CHS_BOOT_JTAG_VSEQ_SV
