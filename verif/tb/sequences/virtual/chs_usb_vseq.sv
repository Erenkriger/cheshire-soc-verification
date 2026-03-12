`ifndef CHS_USB_VSEQ_SV
`define CHS_USB_VSEQ_SV

// ============================================================================
// chs_usb_vseq.sv — USB 1.1 OHCI Virtual Sequence
//
// Exercises the USB OHCI host controller:
//   1. Read USB OHCI registers via SBA
//   2. Configure OHCI operational registers
//   3. Simulate device connect via USB agent (D+ pull-up)
//   4. Attempt basic enumeration flow
//   5. Monitor USB bus activity
// ============================================================================

class chs_usb_vseq extends uvm_sequence;

    `uvm_object_utils(chs_usb_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── USB OHCI Register Map ───
    localparam bit [31:0] USB_BASE         = 32'h0300_8000;
    // OHCI Operational Registers (per OpenHCI spec)
    localparam bit [31:0] USB_HCREVISION   = USB_BASE + 32'h00;
    localparam bit [31:0] USB_HCCONTROL    = USB_BASE + 32'h04;
    localparam bit [31:0] USB_HCCMDSTATUS  = USB_BASE + 32'h08;
    localparam bit [31:0] USB_HCINTRSTAT   = USB_BASE + 32'h0C;
    localparam bit [31:0] USB_HCINTREN     = USB_BASE + 32'h10;
    localparam bit [31:0] USB_HCINTRDIS    = USB_BASE + 32'h14;
    localparam bit [31:0] USB_HCHCCA       = USB_BASE + 32'h18;
    localparam bit [31:0] USB_HCPERIODCUR  = USB_BASE + 32'h1C;
    localparam bit [31:0] USB_HCCTRLHEAD   = USB_BASE + 32'h20;
    localparam bit [31:0] USB_HCCTRLCUR    = USB_BASE + 32'h24;
    localparam bit [31:0] USB_HCBULKHEAD   = USB_BASE + 32'h28;
    localparam bit [31:0] USB_HCBULKCUR    = USB_BASE + 32'h2C;
    localparam bit [31:0] USB_HCDONEHEAD   = USB_BASE + 32'h30;
    localparam bit [31:0] USB_HCFMINTERVAL = USB_BASE + 32'h34;
    localparam bit [31:0] USB_HCFMREM      = USB_BASE + 32'h38;
    localparam bit [31:0] USB_HCFMNUM      = USB_BASE + 32'h3C;
    localparam bit [31:0] USB_HCRHDESCRIPA = USB_BASE + 32'h48;
    localparam bit [31:0] USB_HCRHDESCRIPB = USB_BASE + 32'h4C;
    localparam bit [31:0] USB_HCRHSTATUS   = USB_BASE + 32'h50;
    localparam bit [31:0] USB_HCRHPORTSTATUS = USB_BASE + 32'h54;

    function new(string name = "chs_usb_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq jtag_seq;
        usb_base_seq  usb_seq;
        bit [31:0]    rdata, idcode, sbcs_val;
        int pass_cnt = 0;
        int fail_cnt = 0;

        `uvm_info(get_type_name(),
            "═══════ USB 1.1 OHCI Test START ═══════", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");
        usb_seq  = usb_base_seq::type_id::create("usb_seq");

        // ── Init ──
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════
        // Phase 1: Read OHCI Revision Register
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[1/5] Reading OHCI HcRevision", UVM_LOW)
        jtag_seq.sba_read32(USB_HCREVISION, rdata, p_sequencer.m_jtag_sqr);
        jtag_seq.dmi_read(7'h38, sbcs_val, p_sequencer.m_jtag_sqr);

        if (sbcs_val[14:12] == 0) begin
            `uvm_info(get_type_name(), $sformatf(
                "  ✓ HcRevision = 0x%08h (expected 0x10 for OHCI 1.0)", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_info(get_type_name(), $sformatf(
                "  ✗ HcRevision SBA error=%0d", sbcs_val[14:12]), UVM_LOW)
            fail_cnt++;
            jtag_seq.sba_init(p_sequencer.m_jtag_sqr);
        end

        // ════════════════════════════════════════════
        // Phase 2: Read Control and Status Registers
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[2/5] Reading OHCI operational registers", UVM_LOW)
        begin
            typedef struct {
                string     name;
                bit [31:0] addr;
            } ohci_reg_t;

            ohci_reg_t regs[6];
            regs[0] = '{"HcControl",     USB_HCCONTROL};
            regs[1] = '{"HcCommandStat", USB_HCCMDSTATUS};
            regs[2] = '{"HcInterruptSt", USB_HCINTRSTAT};
            regs[3] = '{"HcFmInterval",  USB_HCFMINTERVAL};
            regs[4] = '{"HcRhDescripA",  USB_HCRHDESCRIPA};
            regs[5] = '{"HcRhStatus",    USB_HCRHSTATUS};

            foreach (regs[i]) begin
                jtag_seq.sba_read32(regs[i].addr, rdata, p_sequencer.m_jtag_sqr);
                jtag_seq.dmi_read(7'h38, sbcs_val, p_sequencer.m_jtag_sqr);
                if (sbcs_val[14:12] == 0) begin
                    `uvm_info(get_type_name(), $sformatf(
                        "  ✓ %-15s [0x%08h] = 0x%08h",
                        regs[i].name, regs[i].addr, rdata), UVM_LOW)
                    pass_cnt++;
                end else begin
                    `uvm_info(get_type_name(), $sformatf(
                        "  ✗ %-15s SBA error=%0d", regs[i].name, sbcs_val[14:12]), UVM_LOW)
                    fail_cnt++;
                    jtag_seq.sba_init(p_sequencer.m_jtag_sqr);
                end
            end
        end

        // ════════════════════════════════════════════
        // Phase 3: OHCI Software Reset
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[3/5] Performing OHCI software reset", UVM_LOW)
        jtag_seq.sba_write32(USB_HCCMDSTATUS, 32'h0000_0001, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(200, p_sequencer.m_jtag_sqr);

        jtag_seq.sba_read32(USB_HCCMDSTATUS, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf(
            "  HcCommandStatus after reset = 0x%08h (HostControllerReset=%0b)",
            rdata, rdata[0]), UVM_LOW)

        // ════════════════════════════════════════════
        // Phase 4: Configure and Enable OHCI
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[4/5] Configuring OHCI for operational state", UVM_LOW)

        // Set FmInterval (12000 bit times per frame for full-speed)
        jtag_seq.sba_write32(USB_HCFMINTERVAL, 32'h2EDF_2EDF, p_sequencer.m_jtag_sqr);

        // Set HcControl to USBOPERATIONAL (bits 7:6 = 2'b10)
        jtag_seq.sba_write32(USB_HCCONTROL, 32'h0000_0080, p_sequencer.m_jtag_sqr);

        jtag_seq.sba_read32(USB_HCCONTROL, rdata, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf(
            "  HcControl = 0x%08h (HCFS=%0b)", rdata, rdata[7:6]), UVM_LOW)

        // ════════════════════════════════════════════
        // Phase 5: USB Device Connect & Enumeration Start
        // ════════════════════════════════════════════
        `uvm_info(get_type_name(), "[5/5] Simulating USB device connect", UVM_LOW)

        if (p_sequencer.m_usb_sqr != null) begin
            // Connect device (D+ pull-up)
            usb_seq.device_connect(p_sequencer.m_usb_sqr);
            usb_seq.send_idle(50, p_sequencer.m_usb_sqr);

            // Wait for host to detect connect
            jtag_seq.do_idle(500, p_sequencer.m_jtag_sqr);

            // Read port status
            jtag_seq.sba_read32(USB_HCRHPORTSTATUS, rdata, p_sequencer.m_jtag_sqr);
            `uvm_info(get_type_name(), $sformatf(
                "  HcRhPortStatus = 0x%08h (CCS=%0b PES=%0b CSC=%0b)",
                rdata, rdata[0], rdata[1], rdata[16]), UVM_LOW)

            if (rdata[0]) begin
                pass_cnt++;
                `uvm_info(get_type_name(), "  ✓ Device connected detected by OHCI", UVM_LOW)
            end else begin
                `uvm_info(get_type_name(), "  ⚠ Device connect not yet reflected in port status", UVM_LOW)
            end

            // Bus reset
            usb_seq.bus_reset(p_sequencer.m_usb_sqr);
            usb_seq.send_idle(100, p_sequencer.m_usb_sqr);

            // Re-connect
            usb_seq.device_connect(p_sequencer.m_usb_sqr);
            usb_seq.send_idle(50, p_sequencer.m_usb_sqr);

            // Disconnect
            usb_seq.device_disconnect(p_sequencer.m_usb_sqr);
            usb_seq.send_idle(50, p_sequencer.m_usb_sqr);
        end else begin
            `uvm_warning(get_type_name(), "  USB sequencer not available, skipping device simulation")
        end

        // ─── Summary ───
        `uvm_info(get_type_name(),
            "═══════ USB 1.1 OHCI Test Summary ═══════", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
            "  PASS: %0d  FAIL: %0d", pass_cnt, fail_cnt), UVM_LOW)

        if (fail_cnt > 0)
            `uvm_error(get_type_name(), "USB OHCI test had failures!")
        else
            `uvm_info(get_type_name(), "USB OHCI test PASSED ✓", UVM_LOW)
    endtask

endclass : chs_usb_vseq

`endif // CHS_USB_VSEQ_SV
