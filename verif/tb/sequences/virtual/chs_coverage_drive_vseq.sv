// ============================================================================
// chs_coverage_drive_vseq.sv -- Coverage-Driven Virtual Sequence
//
// Asama 5: Designed to maximize functional coverage by exercising
// corner-case patterns across all 5 protocols via JTAG SBA path.
//
// Targets:
//   - JTAG: All IR values (IDCODE, DTMCS, DMI, BYPASS), DR lengths
//   - GPIO: All-zero, all-one, checkerboard, walking-one patterns
//   - UART: Printable + control + high-range data bytes
//   - SPI:  Single-byte + multi-byte transfers on CS[0]
//   - I2C:  Write to EEPROM-range address
// ============================================================================

`ifndef CHS_COVERAGE_DRIVE_VSEQ_SV
`define CHS_COVERAGE_DRIVE_VSEQ_SV

class chs_coverage_drive_vseq extends uvm_sequence;

    `uvm_object_utils(chs_coverage_drive_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_coverage_drive_vseq");
        super.new(name);
    endfunction

    // SBA helper tasks (reused from existing SBA sequences)
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
        // Read result
        dmi_word = {23'b0, 7'b0, 32'b0, 2'b00};
        jtag_dr_scan(41, dmi_word, rdata);
        data = rdata[33:2];
    endtask

    task sba_write32(bit [31:0] addr, bit [31:0] data);
        dmi_write(7'h39, addr);
        dmi_write(7'h3C, data);
        do_idle(20);
    endtask

    task sba_read32(bit [31:0] addr, output bit [31:0] data);
        bit [31:0] sbcs_val;
        dmi_write(7'h39, addr);
        do_idle(20);
        dmi_read(7'h3C, data);
    endtask

    virtual task body();
        bit [63:0] rdata;
        bit [31:0] read_data;

        `uvm_info(get_type_name(), "===== Coverage-Driven Sequence START =====", UVM_LOW)

        // Override p_sequencer for JTAG
        m_sequencer = p_sequencer.m_jtag_sqr;

        // ─── Phase 1: JTAG IR/DR Coverage ───
        `uvm_info(get_type_name(), "[1/5] JTAG IR/DR Coverage", UVM_LOW)

        // TAP Reset
        jtag_reset();

        // Select IDCODE IR and scan
        jtag_ir_scan(5'h01);
        jtag_dr_scan(33, 64'h0, rdata);
        `uvm_info(get_type_name(), $sformatf("  IDCODE = 0x%08h", rdata[31:0]), UVM_LOW)

        // Select DTMCS
        jtag_ir_scan(5'h10);
        jtag_dr_scan(32, 64'h0, rdata);
        `uvm_info(get_type_name(), $sformatf("  DTMCS  = 0x%08h", rdata[31:0]), UVM_LOW)

        // Select DMI (used throughout)
        jtag_ir_scan(5'h11);

        // BYPASS (coverage bin)
        jtag_ir_scan(5'h1f);
        jtag_dr_scan(1, 64'h0, rdata);

        // Back to DMI for SBA
        jtag_ir_scan(5'h11);

        // Setup SBA: enable, 32-bit access
        dmi_write(7'h38, 32'h0004_0000);
        do_idle(5);

        // ─── Phase 2: GPIO Coverage Patterns ───
        `uvm_info(get_type_name(), "[2/5] GPIO Coverage Patterns", UVM_LOW)

        // Set all 32 GPIO as output
        sba_write32(32'h0300_5008, 32'hFFFF_FFFF);
        do_idle(5);

        // All-zero
        sba_write32(32'h0300_5004, 32'h0000_0000);
        do_idle(5);

        // All-one
        sba_write32(32'h0300_5004, 32'hFFFF_FFFF);
        do_idle(5);

        // Checkerboard patterns
        sba_write32(32'h0300_5004, 32'h5555_5555);
        do_idle(5);
        sba_write32(32'h0300_5004, 32'hAAAA_AAAA);
        do_idle(5);

        // Walking ones (first 4 bits)
        sba_write32(32'h0300_5004, 32'h0000_0001);
        do_idle(3);
        sba_write32(32'h0300_5004, 32'h0000_0002);
        do_idle(3);
        sba_write32(32'h0300_5004, 32'h0000_0004);
        do_idle(3);
        sba_write32(32'h0300_5004, 32'h0000_0008);
        do_idle(3);

        // Half patterns (for en_pattern cross coverage)
        sba_write32(32'h0300_5008, 32'h0000_FFFF);
        sba_write32(32'h0300_5004, 32'hDEAD_BEEF);
        do_idle(5);

        sba_write32(32'h0300_5008, 32'hFFFF_0000);
        sba_write32(32'h0300_5004, 32'hCAFE_BABE);
        do_idle(5);

        // Lower byte only
        sba_write32(32'h0300_5008, 32'h0000_00FF);
        sba_write32(32'h0300_5004, 32'h0000_0055);
        do_idle(5);

        // Restore all output
        sba_write32(32'h0300_5008, 32'hFFFF_FFFF);
        do_idle(3);

        // ─── Phase 3: UART Coverage Patterns ───
        `uvm_info(get_type_name(), "[3/5] UART Coverage Patterns", UVM_LOW)

        // Configure UART: 115200, 8N1
        sba_write32(32'h0300_2000 + 12, 32'h80);
        do_idle(3);
        sba_write32(32'h0300_2000 + 0, 32'h1B);
        sba_write32(32'h0300_2000 + 4, 32'h00);
        sba_write32(32'h0300_2000 + 12, 32'h03);
        do_idle(3);

        // Send control char (0x01)
        sba_write32(32'h0300_2000 + 0, 32'h01);
        do_idle(5000);

        // Send printable_low ('!')
        sba_write32(32'h0300_2000 + 0, 32'h21);
        do_idle(5000);

        // Send printable_mid ('Z')
        sba_write32(32'h0300_2000 + 0, 32'h5A);
        do_idle(5000);

        // Send printable_hi ('z')
        sba_write32(32'h0300_2000 + 0, 32'h7A);
        do_idle(5000);

        // Send high_range (0xAA)
        sba_write32(32'h0300_2000 + 0, 32'hAA);
        do_idle(5000);

        // Send all_ones (0xFF)
        sba_write32(32'h0300_2000 + 0, 32'hFF);
        do_idle(5000);

        // ─── Phase 4: SPI Coverage Patterns ───
        `uvm_info(get_type_name(), "[4/5] SPI Coverage Patterns", UVM_LOW)

        // Enable SPI Host
        sba_write32(32'h0300_4000 + 32'h10, 32'h8000_0001);
        do_idle(3);
        sba_write32(32'h0300_4000 + 32'h14, 32'h0018_0000);
        do_idle(3);

        // Single-byte transfer
        sba_write32(32'h0300_4000 + 32'h1C, 32'h0000_0042);
        do_idle(3);
        sba_write32(32'h0300_4000 + 32'h18, {4'b0, 9'd7, 2'b01, 1'b0, 2'b01, 1'b1, 1'b0, 12'h004});
        do_idle(1000);

        // 4-byte transfer
        sba_write32(32'h0300_4000 + 32'h1C, 32'hCAFE_BABE);
        do_idle(3);
        sba_write32(32'h0300_4000 + 32'h18, {4'b0, 9'd31, 2'b01, 1'b0, 2'b01, 1'b1, 1'b0, 12'h004});
        do_idle(2000);

        // ─── Phase 5: I2C Coverage (write attempt) ───
        `uvm_info(get_type_name(), "[5/5] I2C Coverage", UVM_LOW)

        // Configure I2C timing
        sba_write32(32'h0300_3000 + 32'h18, 32'h0000_0001);
        sba_write32(32'h0300_3000 + 32'h00, {16'h0, 16'd250});
        sba_write32(32'h0300_3000 + 32'h04, {16'd250, 16'd250});
        sba_write32(32'h0300_3000 + 32'h08, {16'd250, 16'd250});
        sba_write32(32'h0300_3000 + 32'h0C, {16'h0, 16'd5});
        do_idle(5);

        // Write FDATA: START + address 0x50 + W
        sba_write32(32'h0300_3000 + 32'h1C, {19'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 8'hA0});
        do_idle(200);

        // Write data byte
        sba_write32(32'h0300_3000 + 32'h1C, {19'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 8'hDE});
        do_idle(200);

        `uvm_info(get_type_name(), "===== Coverage-Driven Sequence COMPLETE =====", UVM_LOW)
    endtask

endclass : chs_coverage_drive_vseq

`endif // CHS_COVERAGE_DRIVE_VSEQ_SV
