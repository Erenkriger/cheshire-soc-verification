`ifndef CHS_I2C_SBA_VSEQ_SV
`define CHS_I2C_SBA_VSEQ_SV

// ============================================================================
// chs_i2c_sba_vseq.sv — I2C SBA System Bus Access Virtual Sequence
//
// Exercises the full SoC path for I2C peripheral:
//   JTAG → DMI → Debug Module → SBA → AXI Crossbar
//     → AXI-to-Regbus Bridge → I2C CSR → I2C Pins (SCL/SDA)
//
// OpenTitan I2C register map (base 0x0300_3000):
//   INTR_STATE  = 0x00   INTR_ENABLE = 0x04   INTR_TEST  = 0x08
//   ALERT_TEST  = 0x0C   CTRL        = 0x10   STATUS     = 0x14
//   RDATA       = 0x18   FDATA       = 0x1C   FIFO_CTRL  = 0x20
//   FIFO_STATUS = 0x24   OVRD        = 0x28   VAL        = 0x2C
//   TIMING0     = 0x30   TIMING1     = 0x34   TIMING2    = 0x38
//   TIMING3     = 0x3C   TIMING4     = 0x40   TIMEOUT_CTRL=0x44
//   TARGET_ID   = 0x48   ACQDATA     = 0x4C   TXDATA     = 0x50
//
// FDATA Format (Host TX FIFO — Format Data):
//   [7:0]=FBYTE  [8]=START  [9]=STOP  [10]=READ  [11]=RCONT  [12]=NAKOK
//
// Test strategy:
//   1. Probe I2C accessibility via STATUS register
//   2. Configure timing registers for 50MHz sys clock, ~100kHz SCL
//   3. Enable I2C host mode (CTRL.ENABLEHOST=1)
//   4. Write address+data into FDATA to initiate I2C bus transaction
//   5. Monitor I2C bus activity via I2C Monitor
//
// NOTE: No real I2C slave device exists on the bus. The monitor will see
//   START + address + NACK (nobody ACKs). The i2c_if.sv open-drain model
//   defaults to pull-up (idle high). This test verifies:
//   - SBA → I2C CSR path works
//   - I2C master generates SCL clock and SDA transitions
//   - I2C Monitor captures the bus activity
// ============================================================================

class chs_i2c_sba_vseq extends uvm_sequence;

    `uvm_object_utils(chs_i2c_sba_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    // ─── I2C Register Addresses ───
    localparam bit [31:0] I2C_BASE         = 32'h0300_3000;
    localparam bit [31:0] I2C_INTR_STATE   = I2C_BASE + 32'h00;
    localparam bit [31:0] I2C_INTR_ENABLE  = I2C_BASE + 32'h04;
    localparam bit [31:0] I2C_CTRL         = I2C_BASE + 32'h10;
    localparam bit [31:0] I2C_STATUS       = I2C_BASE + 32'h14;
    localparam bit [31:0] I2C_RDATA        = I2C_BASE + 32'h18;
    localparam bit [31:0] I2C_FDATA        = I2C_BASE + 32'h1C;
    localparam bit [31:0] I2C_FIFO_CTRL    = I2C_BASE + 32'h20;
    localparam bit [31:0] I2C_FIFO_STATUS  = I2C_BASE + 32'h24;
    localparam bit [31:0] I2C_OVRD         = I2C_BASE + 32'h28;
    localparam bit [31:0] I2C_VAL          = I2C_BASE + 32'h2C;
    localparam bit [31:0] I2C_TIMING0      = I2C_BASE + 32'h30;
    localparam bit [31:0] I2C_TIMING1      = I2C_BASE + 32'h34;
    localparam bit [31:0] I2C_TIMING2      = I2C_BASE + 32'h38;
    localparam bit [31:0] I2C_TIMING3      = I2C_BASE + 32'h3C;
    localparam bit [31:0] I2C_TIMING4      = I2C_BASE + 32'h40;
    localparam bit [31:0] I2C_TIMEOUT_CTRL = I2C_BASE + 32'h44;

    // ─── FDATA Bit Positions ───
    localparam int FDATA_START = 8;
    localparam int FDATA_STOP  = 9;
    localparam int FDATA_READ  = 10;
    localparam int FDATA_RCONT = 11;
    localparam int FDATA_NAKOK = 12;

    function new(string name = "chs_i2c_sba_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq  jtag_seq;
        bit [31:0]     rdata;
        bit [31:0]     idcode;

        `uvm_info(get_type_name(),
                  "===== I2C SBA Test START =====", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ── Step 1: TAP Reset + SBA Init ──
        `uvm_info(get_type_name(), "[1/5] TAP Reset + SBA Init", UVM_MEDIUM)
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf("IDCODE = 0x%08h", idcode), UVM_LOW)
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ── Step 2: Probe I2C Accessibility ──
        `uvm_info(get_type_name(), "[2/5] Probing I2C accessibility (STATUS reg)", UVM_MEDIUM)
        i2c_probe_test(jtag_seq);

        // ── Step 3: Configure I2C Timing ──
        `uvm_info(get_type_name(), "[3/5] Configuring I2C timing for ~100kHz SCL", UVM_MEDIUM)
        i2c_configure(jtag_seq);

        // ── Step 4: I2C Write Transaction ──
        `uvm_info(get_type_name(), "[4/5] I2C Write Transaction (addr=0x50, data=0xA5)", UVM_MEDIUM)
        i2c_write_test(jtag_seq);

        // ── Step 5: I2C Multi-Byte Write ──
        `uvm_info(get_type_name(), "[5/5] I2C Multi-Byte Write (addr=0x68, 3 bytes)", UVM_MEDIUM)
        i2c_write_multi(jtag_seq);

        `uvm_info(get_type_name(),
                  "===== I2C SBA Test COMPLETE =====", UVM_LOW)
    endtask : body

    // ────────────────────────────────────────────────────────────────
    // Probe I2C — read STATUS register
    // After reset: FMTEMPTY=1(bit2), HOSTIDLE=1(bit3), TARGETIDLE=1(bit4),
    //              RXEMPTY=1(bit5), TXEMPTY=1(bit8), ACQEMPTY=1(bit9)
    // Expected: 0x0000_033C
    // ────────────────────────────────────────────────────────────────
    virtual task i2c_probe_test(jtag_base_seq jtag_seq);
        bit [31:0] status_val;
        bit [31:0] ctrl_val;

        jtag_seq.sba_read32(I2C_STATUS, status_val, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
            $sformatf("I2C STATUS = 0x%08h (HOSTIDLE=%0b FMTEMPTY=%0b RXEMPTY=%0b)",
            status_val, status_val[3], status_val[2], status_val[5]), UVM_LOW)

        // Verify HOST is idle after reset
        if (status_val[3] !== 1'b1)
            `uvm_warning(get_type_name(),
                $sformatf("I2C: HOSTIDLE not set after reset (STATUS=0x%08h)", status_val))

        // Also read CTRL to confirm initial state
        jtag_seq.sba_read32(I2C_CTRL, ctrl_val, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
            $sformatf("I2C CTRL = 0x%08h (ENABLEHOST=%0b ENABLETARGET=%0b)",
            ctrl_val, ctrl_val[0], ctrl_val[1]), UVM_LOW)
    endtask : i2c_probe_test

    // ────────────────────────────────────────────────────────────────
    // Configure I2C timing for ~100kHz SCL @ 50MHz system clock
    //
    // Standard-mode I2C (100kHz):
    //   SCL period = 10µs → 500 sys clocks
    //   THIGH = 250, TLOW = 250 (equal duty cycle)
    //   T_R = 10 (rise time), T_F = 10 (fall time)
    //   TSU_STA = 25, THD_STA = 25 (START setup/hold)
    //   TSU_DAT = 5,  THD_DAT = 5  (data setup/hold)
    //   TSU_STO = 25 (STOP setup)
    //   T_BUF = 25 (bus free time)
    // ────────────────────────────────────────────────────────────────
    virtual task i2c_configure(jtag_base_seq jtag_seq);
        bit [31:0] timing_val;

        // Reset FIFOs
        jtag_seq.sba_write32(I2C_FIFO_CTRL, 32'h0000_0103, p_sequencer.m_jtag_sqr);
        jtag_seq.do_idle(20, p_sequencer.m_jtag_sqr);
        // Clear FIFO reset bits
        jtag_seq.sba_write32(I2C_FIFO_CTRL, 32'h0000_0000, p_sequencer.m_jtag_sqr);

        // TIMING0: TLOW[31:16]=250, THIGH[15:0]=250
        timing_val = {16'd250, 16'd250};
        `uvm_info(get_type_name(),
            $sformatf("I2C: TIMING0 = 0x%08h (TLOW=250, THIGH=250)", timing_val), UVM_MEDIUM)
        jtag_seq.sba_write32(I2C_TIMING0, timing_val, p_sequencer.m_jtag_sqr);

        // TIMING1: T_F[31:16]=10, T_R[15:0]=10
        timing_val = {16'd10, 16'd10};
        jtag_seq.sba_write32(I2C_TIMING1, timing_val, p_sequencer.m_jtag_sqr);

        // TIMING2: THD_STA[31:16]=25, TSU_STA[15:0]=25
        timing_val = {16'd25, 16'd25};
        jtag_seq.sba_write32(I2C_TIMING2, timing_val, p_sequencer.m_jtag_sqr);

        // TIMING3: THD_DAT[31:16]=5, TSU_DAT[15:0]=5
        timing_val = {16'd5, 16'd5};
        jtag_seq.sba_write32(I2C_TIMING3, timing_val, p_sequencer.m_jtag_sqr);

        // TIMING4: T_BUF[31:16]=25, TSU_STO[15:0]=25
        timing_val = {16'd25, 16'd25};
        jtag_seq.sba_write32(I2C_TIMING4, timing_val, p_sequencer.m_jtag_sqr);

        // Clear any pending interrupts
        jtag_seq.sba_write32(I2C_INTR_STATE, 32'h0000_7FFF, p_sequencer.m_jtag_sqr);

        // Enable NAKOK interrupt so we can see NACK events (optional, for debug)
        // INTR_ENABLE bit 4 = nak
        jtag_seq.sba_write32(I2C_INTR_ENABLE, 32'h0000_0000, p_sequencer.m_jtag_sqr);

        // Enable I2C Host mode
        jtag_seq.sba_write32(I2C_CTRL, 32'h0000_0001, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "I2C: Configuration complete (host mode, ~100kHz)", UVM_MEDIUM)
    endtask : i2c_configure

    // ────────────────────────────────────────────────────────────────
    // Single I2C Write Transaction
    // Send: START + [0x50<<1|W] + [0xA5] + STOP
    //
    // FDATA word 1: addr byte with START
    //   {NAKOK=1, RCONT=0, READ=0, STOP=0, START=1, FBYTE=0xA0}
    //   = 0x11A0 (NAKOK allows test to continue even without slave ACK)
    //
    // FDATA word 2: data byte with STOP
    //   {NAKOK=1, RCONT=0, READ=0, STOP=1, START=0, FBYTE=0xA5}
    //   = 0x12A5
    // ────────────────────────────────────────────────────────────────
    virtual task i2c_write_test(jtag_base_seq jtag_seq);
        bit [31:0] fdata_word;
        bit [31:0] status_val;
        bit [31:0] intr_val;
        int poll_count;

        // FDATA word 1: START + slave address 0x50, Write (bit0=0)
        // NAKOK=1 to tolerate missing slave
        fdata_word = 32'h0;
        fdata_word[7:0]       = {7'h50, 1'b0};  // addr=0x50, W=0 → 0xA0
        fdata_word[FDATA_START] = 1'b1;           // Issue START
        fdata_word[FDATA_NAKOK] = 1'b1;           // Allow NACK
        `uvm_info(get_type_name(),
            $sformatf("I2C: FDATA[0] = 0x%08h (START + addr=0x50 + W)", fdata_word), UVM_MEDIUM)
        jtag_seq.sba_write32(I2C_FDATA, fdata_word, p_sequencer.m_jtag_sqr);

        // FDATA word 2: data byte 0xA5 + STOP
        fdata_word = 32'h0;
        fdata_word[7:0]       = 8'hA5;
        fdata_word[FDATA_STOP]  = 1'b1;           // Issue STOP after this byte
        fdata_word[FDATA_NAKOK] = 1'b1;           // Allow NACK
        `uvm_info(get_type_name(),
            $sformatf("I2C: FDATA[1] = 0x%08h (DATA=0xA5 + STOP)", fdata_word), UVM_MEDIUM)
        jtag_seq.sba_write32(I2C_FDATA, fdata_word, p_sequencer.m_jtag_sqr);

        // Wait for I2C transaction to complete on the bus
        // At ~100kHz: START + 9 clocks (addr) + 9 clocks (data) + STOP ≈ 200µs
        `uvm_info(get_type_name(), "I2C: Waiting for bus transaction...", UVM_MEDIUM)
        jtag_seq.do_idle(1000, p_sequencer.m_jtag_sqr);

        // Poll until HOSTIDLE
        poll_count = 0;
        do begin
            jtag_seq.sba_read32(I2C_STATUS, status_val, p_sequencer.m_jtag_sqr);
            `uvm_info(get_type_name(),
                $sformatf("I2C: STATUS poll #%0d = 0x%08h (HOSTIDLE=%0b FMTEMPTY=%0b)",
                poll_count+1, status_val, status_val[3], status_val[2]), UVM_HIGH)
            poll_count++;
            if (poll_count > 30) begin
                `uvm_warning(get_type_name(),
                    $sformatf("I2C: HOSTIDLE not set after %0d polls", poll_count))
                break;
            end
            if (!status_val[3])
                jtag_seq.do_idle(200, p_sequencer.m_jtag_sqr);
        end while (!status_val[3]);

        // Check interrupt state (NAK expected since no slave)
        jtag_seq.sba_read32(I2C_INTR_STATE, intr_val, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(),
            $sformatf("I2C: INTR_STATE = 0x%08h (post-write)", intr_val), UVM_LOW)

        // Clear interrupts
        jtag_seq.sba_write32(I2C_INTR_STATE, intr_val, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "I2C: Single write transaction complete", UVM_MEDIUM)
    endtask : i2c_write_test

    // ────────────────────────────────────────────────────────────────
    // Multi-byte I2C Write
    // Send: START + [0x68<<1|W] + [0x01] + [0x02] + [0x03] + STOP
    // Slave address 0x68 (common for IMU/accelerometer)
    // ────────────────────────────────────────────────────────────────
    virtual task i2c_write_multi(jtag_base_seq jtag_seq);
        bit [31:0] fdata_word;
        bit [31:0] status_val;
        int poll_count;

        // FDATA: START + addr 0x68 + W
        fdata_word = 32'h0;
        fdata_word[7:0]        = {7'h68, 1'b0};  // 0xD0
        fdata_word[FDATA_START]  = 1'b1;
        fdata_word[FDATA_NAKOK]  = 1'b1;
        jtag_seq.sba_write32(I2C_FDATA, fdata_word, p_sequencer.m_jtag_sqr);

        // FDATA: data byte 0x01 (no STOP, more data follows)
        fdata_word = 32'h0;
        fdata_word[7:0]        = 8'h01;
        fdata_word[FDATA_NAKOK]  = 1'b1;
        jtag_seq.sba_write32(I2C_FDATA, fdata_word, p_sequencer.m_jtag_sqr);

        // FDATA: data byte 0x02
        fdata_word = 32'h0;
        fdata_word[7:0]        = 8'h02;
        fdata_word[FDATA_NAKOK]  = 1'b1;
        jtag_seq.sba_write32(I2C_FDATA, fdata_word, p_sequencer.m_jtag_sqr);

        // FDATA: data byte 0x03 + STOP
        fdata_word = 32'h0;
        fdata_word[7:0]        = 8'h03;
        fdata_word[FDATA_STOP]   = 1'b1;
        fdata_word[FDATA_NAKOK]  = 1'b1;
        jtag_seq.sba_write32(I2C_FDATA, fdata_word, p_sequencer.m_jtag_sqr);

        `uvm_info(get_type_name(), "I2C: Multi-byte write dispatched, waiting...", UVM_MEDIUM)

        // Wait for bus transaction (~400µs at 100kHz for 4 bytes + overhead)
        jtag_seq.do_idle(2000, p_sequencer.m_jtag_sqr);

        // Poll for completion
        poll_count = 0;
        do begin
            jtag_seq.sba_read32(I2C_STATUS, status_val, p_sequencer.m_jtag_sqr);
            poll_count++;
            if (poll_count > 30) begin
                `uvm_warning(get_type_name(),
                    $sformatf("I2C: HOSTIDLE timeout after %0d polls (STATUS=0x%08h)",
                    poll_count, status_val))
                break;
            end
            if (!status_val[3])
                jtag_seq.do_idle(200, p_sequencer.m_jtag_sqr);
        end while (!status_val[3]);

        `uvm_info(get_type_name(),
            $sformatf("I2C: Multi-write complete (STATUS=0x%08h)", status_val), UVM_LOW)
    endtask : i2c_write_multi

endclass : chs_i2c_sba_vseq

`endif // CHS_I2C_SBA_VSEQ_SV
