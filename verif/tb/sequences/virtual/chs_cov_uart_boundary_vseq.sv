// ============================================================================
// chs_cov_uart_boundary_vseq.sv — UART Boundary & All-Bins Coverage Booster
//
// Targets uncovered bins:
//   - Data: zero(00), control_chars(01-1F), printable_low(20-3F),
//           printable_mid(40-5F), printable_hi(60-7E), del(7F),
//           high_range(80-FE), all_ones(FF)
//   - Direction: TX (DUT transmit via THR), RX (TB→DUT — already covered)
//   - Parity/Frame errors: These need specific config — we focus on data bins
//   - Cross: data_x_dir for every data range × TX direction
// ============================================================================

`ifndef CHS_COV_UART_BOUNDARY_VSEQ_SV
`define CHS_COV_UART_BOUNDARY_VSEQ_SV

class chs_cov_uart_boundary_vseq extends uvm_sequence;

    `uvm_object_utils(chs_cov_uart_boundary_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_cov_uart_boundary_vseq");
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
        do_idle(20);
    endtask

    task sba_read32(bit [31:0] addr, output bit [31:0] data);
        dmi_write(7'h39, addr);
        do_idle(20);
        dmi_read(7'h3C, data);
    endtask

    // UART register offsets
    localparam bit [31:0] UART_BASE = 32'h0300_2000;
    localparam int THR_OFS = 0;
    localparam int IER_OFS = 4;
    localparam int LCR_OFS = 12;
    localparam int LSR_OFS = 20;
    localparam int DLL_OFS = 0;
    localparam int DLM_OFS = 4;

    // Wait ~1 UART frame time at 115200 baud (~87us = 4350 clk cycles @ 50MHz)
    localparam int FRAME_IDLE = 5000;

    task uart_send_byte(bit [7:0] data);
        sba_write32(UART_BASE + THR_OFS, {24'h0, data});
        do_idle(FRAME_IDLE);
    endtask

    virtual task body();
        bit [31:0] rd32;

        `uvm_info(get_type_name(), "===== UART Boundary Coverage START =====", UVM_LOW)

        m_sequencer = p_sequencer.m_jtag_sqr;

        // ─── Setup: TAP Reset + SBA Init ───
        jtag_reset();
        do_idle(5);
        jtag_ir_scan(5'h11);
        // Activate debug module
        dmi_write(7'h10, 32'h0000_0001);
        do_idle(5);
        // Setup SBA: 32-bit access
        dmi_write(7'h38, 32'h0004_0000);
        do_idle(5);

        // ─── UART Init: 115200, 8N1 ───
        `uvm_info(get_type_name(), "[INIT] UART 115200 8N1", UVM_LOW)
        sba_write32(UART_BASE + LCR_OFS, 32'h80);  // DLAB=1
        do_idle(5);
        sba_write32(UART_BASE + DLL_OFS, 32'h1B);   // 115200 @ 50MHz → DLL=0x1B
        sba_write32(UART_BASE + DLM_OFS, 32'h00);
        sba_write32(UART_BASE + LCR_OFS, 32'h03);  // DLAB=0, 8bit, no parity
        do_idle(5);

        // Enable FIFO
        sba_write32(UART_BASE + 8, 32'h07);  // FCR: FIFO enable + clear
        do_idle(5);

        // ─── Phase 1: Zero byte (0x00) ───
        `uvm_info(get_type_name(), "[1/8] Data = 0x00 (zero)", UVM_LOW)
        uart_send_byte(8'h00);

        // ─── Phase 2: Control chars (0x01-0x1F) ───
        `uvm_info(get_type_name(), "[2/8] Data = control_chars", UVM_LOW)
        uart_send_byte(8'h01);  // SOH
        uart_send_byte(8'h0A);  // LF
        uart_send_byte(8'h0D);  // CR
        uart_send_byte(8'h1F);  // US (boundary)

        // ─── Phase 3: Printable low (0x20-0x3F) ───
        `uvm_info(get_type_name(), "[3/8] Data = printable_low", UVM_LOW)
        uart_send_byte(8'h20);  // Space (lower bound)
        uart_send_byte(8'h30);  // '0'
        uart_send_byte(8'h3F);  // '?' (upper bound)

        // ─── Phase 4: Printable mid (0x40-0x5F) ───
        `uvm_info(get_type_name(), "[4/8] Data = printable_mid", UVM_LOW)
        uart_send_byte(8'h40);  // '@'
        uart_send_byte(8'h41);  // 'A'
        uart_send_byte(8'h5A);  // 'Z'
        uart_send_byte(8'h5F);  // '_' (boundary)

        // ─── Phase 5: Printable hi (0x60-0x7E) ───
        `uvm_info(get_type_name(), "[5/8] Data = printable_hi", UVM_LOW)
        uart_send_byte(8'h60);  // '`'
        uart_send_byte(8'h61);  // 'a'
        uart_send_byte(8'h7A);  // 'z'
        uart_send_byte(8'h7E);  // '~' (boundary)

        // ─── Phase 6: DEL (0x7F) ───
        `uvm_info(get_type_name(), "[6/8] Data = 0x7F (DEL)", UVM_LOW)
        uart_send_byte(8'h7F);

        // ─── Phase 7: High range (0x80-0xFE) ───
        `uvm_info(get_type_name(), "[7/8] Data = high_range", UVM_LOW)
        uart_send_byte(8'h80);  // lower bound
        uart_send_byte(8'h99);
        uart_send_byte(8'hBB);
        uart_send_byte(8'hCC);
        uart_send_byte(8'hFE);  // upper bound

        // ─── Phase 8: All ones (0xFF) ───
        `uvm_info(get_type_name(), "[8/8] Data = 0xFF (all_ones)", UVM_LOW)
        uart_send_byte(8'hFF);

        // ─── Phase 9: Additional boundary values ───
        `uvm_info(get_type_name(), "[BONUS] Walking bit patterns", UVM_LOW)
        uart_send_byte(8'h55);  // alternating 0101
        uart_send_byte(8'hAA);  // alternating 1010
        uart_send_byte(8'hF0);
        uart_send_byte(8'h0F);

        `uvm_info(get_type_name(), "===== UART Boundary Coverage COMPLETE =====", UVM_LOW)
    endtask

endclass : chs_cov_uart_boundary_vseq

`endif // CHS_COV_UART_BOUNDARY_VSEQ_SV
