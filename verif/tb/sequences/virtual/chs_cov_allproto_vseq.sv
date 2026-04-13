// ============================================================================
// chs_cov_allproto_vseq.sv — All-Protocol Coverage Booster
//
// Activates ALL 5 protocols in a single test to maximize cross-protocol
// coverage and hit the "all_active" bin in cg_cross_protocol.
//
// Targets:
//   - Cross-protocol: all_active, jtag_uart_gpio, jtag_spi
//   - SPI: multi-byte, different CS, JEDEC commands
//   - I2C: write + read attempts, different address ranges
//   - Combined: GPIO→UART→SPI→I2C in rapid succession
// ============================================================================

`ifndef CHS_COV_ALLPROTO_VSEQ_SV
`define CHS_COV_ALLPROTO_VSEQ_SV

class chs_cov_allproto_vseq extends uvm_sequence;

    `uvm_object_utils(chs_cov_allproto_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_cov_allproto_vseq");
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

    // Constants
    localparam bit [31:0] UART_BASE = 32'h0300_2000;
    localparam bit [31:0] SPI_BASE  = 32'h0300_4000;
    localparam bit [31:0] I2C_BASE  = 32'h0300_3000;
    localparam bit [31:0] GPIO_BASE = 32'h0300_5000;

    virtual task body();
        bit [31:0] rd32;
        int i;

        `uvm_info(get_type_name(), "===== All-Protocol Coverage Boost START =====", UVM_LOW)

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
        // Phase 1: GPIO — Quick setup + patterns
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[1/5] GPIO Activation", UVM_LOW)
        sba_write32(GPIO_BASE + 32'h20, 32'hFFFF_FFFF);  // All output
        do_idle(3);
        sba_write32(GPIO_BASE + 32'h14, 32'h5555_5555);  // Checkerboard
        do_idle(3);
        sba_write32(GPIO_BASE + 32'h14, 32'hAAAA_AAAA);
        do_idle(3);

        // ═══════════════════════════════════════════════════════
        // Phase 2: UART — Init + multiple data ranges
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[2/5] UART Activation", UVM_LOW)
        // UART init 115200
        sba_write32(UART_BASE + 12, 32'h80);
        do_idle(3);
        sba_write32(UART_BASE + 0, 32'h1B);
        sba_write32(UART_BASE + 4, 32'h00);
        sba_write32(UART_BASE + 12, 32'h03);
        sba_write32(UART_BASE + 8, 32'h07);  // FIFO enable
        do_idle(5);

        // Send representative bytes
        sba_write32(UART_BASE, {24'h0, 8'h48});  // 'H' printable_mid
        do_idle(5000);
        sba_write32(UART_BASE, {24'h0, 8'h69});  // 'i' printable_hi
        do_idle(5000);

        // ═══════════════════════════════════════════════════════
        // Phase 3: SPI — Init + multi-byte transfers
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[3/5] SPI Activation", UVM_LOW)
        // SPI Host enable + CONFIGOPTS
        sba_write32(SPI_BASE + 32'h10, 32'h8000_0001);
        do_idle(3);
        sba_write32(SPI_BASE + 32'h18, 32'h0018_0000);  // CONFIGOPTS: clkdiv=24
        do_idle(3);

        // JEDEC Read ID (0x9F) — single byte TX
        sba_write32(SPI_BASE + 32'h24, 32'h0000_0000);  // CSID=0
        sba_write32(SPI_BASE + 32'h30, {24'h0, 8'h9F});  // TXDATA
        do_idle(3);
        // COMMAND: 1 byte TX, speed=standard, direction=TX, csaat=1
        sba_write32(SPI_BASE + 32'h28, {4'b0, 9'd7, 2'b01, 1'b0, 2'b01, 1'b1, 1'b0, 12'h004});
        do_idle(1500);

        // Multi-byte TX (4 bytes) for medium_tr bin
        sba_write32(SPI_BASE + 32'h30, 32'hDEAD_BEEF);
        do_idle(3);
        sba_write32(SPI_BASE + 32'h28, {4'b0, 9'd31, 2'b01, 1'b0, 2'b01, 1'b1, 1'b0, 12'h004});
        do_idle(3000);

        // Deassert CS
        sba_write32(SPI_BASE + 32'h28, {4'b0, 9'd7, 2'b01, 1'b0, 2'b01, 1'b0, 1'b0, 12'h004});
        do_idle(1500);

        // ═══════════════════════════════════════════════════════
        // Phase 4: I2C — Write + timing config
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[4/5] I2C Activation", UVM_LOW)
        // Enable I2C
        sba_write32(I2C_BASE + 32'h10, 32'h0000_0001);
        do_idle(3);
        // Timing: SCL period ~100kHz
        sba_write32(I2C_BASE + 32'h30, {16'h0, 16'd250});
        sba_write32(I2C_BASE + 32'h34, {16'd250, 16'd250});
        sba_write32(I2C_BASE + 32'h38, {16'd250, 16'd250});
        sba_write32(I2C_BASE + 32'h3C, {16'h0, 16'd5});
        do_idle(5);

        // FDATA: START + addr 0x50 + W
        sba_write32(I2C_BASE + 32'h1C, {19'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 8'hA0});
        do_idle(300);

        // FDATA: data byte + NAKOK (slave may not exist)
        sba_write32(I2C_BASE + 32'h1C, {19'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 8'hAB});
        do_idle(300);

        // FDATA: STOP
        sba_write32(I2C_BASE + 32'h1C, {19'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 8'h00});
        do_idle(300);

        // ─── Try I2C read for op=read coverage ───
        // START + addr 0x50 + R
        sba_write32(I2C_BASE + 32'h1C, {19'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 8'hA1});
        do_idle(300);
        // Read 1 byte + NAKOK + STOP
        sba_write32(I2C_BASE + 32'h1C, {19'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 8'h01});
        do_idle(300);

        // ═══════════════════════════════════════════════════════
        // Phase 5: Cross-Protocol Interleave
        // ═══════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[5/5] Cross-Protocol Interleave (all_active)", UVM_LOW)

        // Rapid GPIO→UART→SPI→I2C alternation
        for (i = 0; i < 3; i++) begin
            // GPIO
            sba_write32(GPIO_BASE + 32'h14, 32'h0000_0001 << i);
            do_idle(3);
            // UART
            sba_write32(UART_BASE, {24'h0, 8'h30 + i[7:0]});
            do_idle(3000);
            // SPI
            sba_write32(SPI_BASE + 32'h30, {24'h0, 8'hA0 + i[7:0]});
            sba_write32(SPI_BASE + 32'h28, {4'b0, 9'd7, 2'b01, 1'b0, 2'b01, 1'b1, 1'b0, 12'h004});
            do_idle(1500);
            // I2C — keep re-sending FDATA
            sba_write32(I2C_BASE + 32'h1C, {19'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 8'hA0});
            do_idle(300);
        end

        // Final GPIO writes
        sba_write32(GPIO_BASE + 32'h14, 32'h0000_0000);
        do_idle(5);

        `uvm_info(get_type_name(), "===== All-Protocol Coverage Boost COMPLETE =====", UVM_LOW)
    endtask

endclass : chs_cov_allproto_vseq

`endif // CHS_COV_ALLPROTO_VSEQ_SV
