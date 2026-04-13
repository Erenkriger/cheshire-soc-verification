// ============================================================================
// chs_cov_axi_region_vseq.sv — AXI Region & Burst Coverage Booster
//
// Targets uncovered bins:
//   - AXI region: DEBUG, BOOTROM, CLINT, PLIC, PERIPHERALS, LLC_SPM, DRAM, UNMAPPED
//   - Region × R/W cross coverage
//   - Different AXI sizes via SBA (32-bit → 4B size on 64-bit bus)
//   - Multiple addresses to exercise different burst types from core
//   - DRAM multi-word to generate INCR bursts
// ============================================================================

`ifndef CHS_COV_AXI_REGION_VSEQ_SV
`define CHS_COV_AXI_REGION_VSEQ_SV

class chs_cov_axi_region_vseq extends uvm_sequence;

    `uvm_object_utils(chs_cov_axi_region_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_cov_axi_region_vseq");
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

    task dmi_read(bit [6:0] addr, output bit [31:0] data);
        bit [63:0] dmi_word, rdata;
        dmi_word = {23'b0, addr, 32'b0, 2'b01};
        jtag_dr_scan(41, dmi_word, rdata);
        do_idle(10);
        dmi_word = {23'b0, 7'b0, 32'b0, 2'b00};
        jtag_dr_scan(41, dmi_word, rdata);
        data = rdata[33:2];
    endtask

    task sba_write32(bit [31:0] addr, bit [31:0] data);
        dmi_write(7'h39, addr);
        dmi_write(7'h3C, data);
        do_idle(30);
    endtask

    task sba_read32(bit [31:0] addr, output bit [31:0] data);
        dmi_write(7'h39, addr);
        do_idle(30);
        dmi_read(7'h3C, data);
    endtask

    virtual task body();
        bit [31:0] rd32;
        int i;

        `uvm_info(get_type_name(), "===== AXI Region & Burst Coverage START =====", UVM_LOW)

        m_sequencer = p_sequencer.m_jtag_sqr;

        // ─── Setup: TAP Reset + SBA Init ───
        jtag_reset();
        do_idle(5);
        jtag_ir_scan(5'h11);
        dmi_write(7'h10, 32'h0000_0001);
        do_idle(5);
        dmi_write(7'h38, 32'h0004_0000);
        do_idle(10);

        // ═══════════════════════════════════════════════════════
        // Region 1: DEBUG (0x0000_0000)
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[1/8] AXI Region: DEBUG (0x0000_0000)", UVM_LOW)
        // Read DMSTATUS — generates AXI read in Debug region
        sba_read32(32'h0000_0000, rd32);
        `uvm_info(get_type_name(), $sformatf("  Debug[0x0] = 0x%08h", rd32), UVM_LOW)
        // Write to Debug region
        sba_write32(32'h0000_0100, 32'hFACE_0001);
        do_idle(10);

        // ═══════════════════════════════════════════════════════
        // Region 2: BOOTROM (0x0200_0000)
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[2/8] AXI Region: BOOTROM (0x0200_0000)", UVM_LOW)
        sba_read32(32'h0200_0000, rd32);
        `uvm_info(get_type_name(), $sformatf("  BOOTROM[0x0] = 0x%08h", rd32), UVM_LOW)
        sba_read32(32'h0200_0004, rd32);
        sba_read32(32'h0200_0008, rd32);
        sba_read32(32'h0200_0010, rd32);

        // ═══════════════════════════════════════════════════════
        // Region 3: CLINT (0x0204_0000)
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[3/8] AXI Region: CLINT (0x0204_0000)", UVM_LOW)
        sba_read32(32'h0204_0000, rd32);
        `uvm_info(get_type_name(), $sformatf("  CLINT[msip] = 0x%08h", rd32), UVM_LOW)
        // Write MSIP
        sba_write32(32'h0204_0000, 32'h0000_0000);
        // Read MTIME
        sba_read32(32'h0204_BFF8, rd32);
        `uvm_info(get_type_name(), $sformatf("  CLINT[mtime_lo] = 0x%08h", rd32), UVM_LOW)
        // Write MTIMECMP
        sba_write32(32'h0204_4000, 32'hFFFF_FFFF);
        do_idle(10);

        // ═══════════════════════════════════════════════════════
        // Region 4: PLIC (0x0400_0000)
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[4/8] AXI Region: PLIC (0x0400_0000)", UVM_LOW)
        // Read PLIC priority reg 0
        sba_read32(32'h0400_0000, rd32);
        `uvm_info(get_type_name(), $sformatf("  PLIC[prio0] = 0x%08h", rd32), UVM_LOW)
        // Write priority for source 1
        sba_write32(32'h0400_0004, 32'h0000_0001);
        // Read pending register
        sba_read32(32'h0400_1000, rd32);
        // Read enable register
        sba_read32(32'h0400_2000, rd32);
        do_idle(10);

        // ═══════════════════════════════════════════════════════
        // Region 5: PERIPHERALS (0x0300_0000)
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[5/8] AXI Region: PERIPHERALS", UVM_LOW)
        // Cheshire regs
        sba_read32(32'h0300_0000, rd32);
        `uvm_info(get_type_name(), $sformatf("  CHS_REGS[0x0] = 0x%08h", rd32), UVM_LOW)
        // UART
        sba_read32(32'h0300_2000 + 20, rd32);  // LSR
        // SPI
        sba_read32(32'h0300_4000 + 32'h14, rd32);  // STATUS
        // GPIO
        sba_read32(32'h0300_5000 + 32'h10, rd32);  // DATA_IN
        // I2C
        sba_read32(32'h0300_3000 + 32'h14, rd32);  // STATUS
        // Write to peripherals
        sba_write32(32'h0300_5014, 32'h0000_AAAA);  // GPIO out
        do_idle(10);

        // ═══════════════════════════════════════════════════════
        // Region 6: LLC/SPM (0x1400_0000)
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[6/8] AXI Region: LLC_SPM (0x1400_0000)", UVM_LOW)
        // Write pattern to SPM
        for (i = 0; i < 8; i++) begin
            sba_write32(32'h1400_0000 + (i * 4), 32'hABCD_0000 + i);
        end
        // Read back
        for (i = 0; i < 4; i++) begin
            sba_read32(32'h1400_0000 + (i * 4), rd32);
            `uvm_info(get_type_name(), $sformatf("  SPM[%0d] = 0x%08h", i, rd32), UVM_LOW)
        end

        // ═══════════════════════════════════════════════════════
        // Region 7: DRAM (0x8000_0000)
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[7/8] AXI Region: DRAM (0x8000_0000)", UVM_LOW)
        // Write a block of data — will create AXI INCR bursts
        for (i = 0; i < 16; i++) begin
            sba_write32(32'h8000_0000 + (i * 4), 32'hD0000000 + i);
        end
        // Read back
        for (i = 0; i < 16; i++) begin
            sba_read32(32'h8000_0000 + (i * 4), rd32);
        end
        `uvm_info(get_type_name(), "  DRAM 16-word write+read complete", UVM_LOW)

        // Write at different DRAM offsets
        sba_write32(32'h8000_1000, 32'hAAAA_BBBB);
        sba_read32(32'h8000_1000, rd32);
        sba_write32(32'h8000_2000, 32'hCCCC_DDDD);
        sba_read32(32'h8000_2000, rd32);

        // ═══════════════════════════════════════════════════════
        // Region 8: UNMAPPED (0x7000_0000 — between peripherals and DRAM)
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[8/8] AXI Region: UNMAPPED (0x7000_0000)", UVM_LOW)
        // Access unmapped region — may get DECERR
        sba_read32(32'h7000_0000, rd32);
        do_idle(20);
        // Check SBCS for error
        dmi_read(7'h38, rd32);
        `uvm_info(get_type_name(), $sformatf("  SBCS after unmapped access = 0x%08h", rd32), UVM_LOW)
        // Clear any SBA error
        if (rd32[22]) begin
            dmi_write(7'h38, rd32 | 32'h0040_0000);
            do_idle(10);
        end

        `uvm_info(get_type_name(), "===== AXI Region & Burst Coverage COMPLETE =====", UVM_LOW)
    endtask

endclass : chs_cov_axi_region_vseq

`endif // CHS_COV_AXI_REGION_VSEQ_SV
