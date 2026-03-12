`ifndef JTAG_BASE_SEQ_SV
`define JTAG_BASE_SEQ_SV

// ============================================================================
// jtag_base_seq.sv — Base JTAG Sequence
// Provides reusable helper tasks for JTAG TAP operations:
//   - do_reset, do_ir_scan, do_dr_scan, do_idle
// ============================================================================

class jtag_base_seq extends uvm_sequence #(jtag_transaction);

    `uvm_object_utils(jtag_base_seq)

    // ----- RISC-V Debug Module constants -----
    localparam bit [4:0] IR_DMI     = 5'h11;
    localparam bit [4:0] IR_IDCODE  = 5'h01;
    localparam bit [4:0] IR_BYPASS  = 5'h1f;
    localparam int       DMI_DR_LEN = 41;  // {addr[6:0], data[31:0], op[1:0]}

    // DMI Operation Codes
    localparam bit [1:0] DMI_OP_NOP   = 2'b00;
    localparam bit [1:0] DMI_OP_READ  = 2'b01;
    localparam bit [1:0] DMI_OP_WRITE = 2'b10;

    // DMI Register Addresses
    localparam bit [6:0] DMI_DMCONTROL  = 7'h10;
    localparam bit [6:0] DMI_DMSTATUS   = 7'h11;
    localparam bit [6:0] DMI_SBCS       = 7'h38;
    localparam bit [6:0] DMI_SBADDRESS0 = 7'h39;
    localparam bit [6:0] DMI_SBADDRESS1 = 7'h3A;
    localparam bit [6:0] DMI_SBDATA0    = 7'h3C;
    localparam bit [6:0] DMI_SBDATA1    = 7'h3D;

    function new(string name = "jtag_base_seq");
        super.new(name);
    endfunction

    // ════════════════════════════════════════════════════════════════
    //  Layer 0: Low-level JTAG TAP operations
    // ════════════════════════════════════════════════════════════════

    // ---- TAP Reset ----
    virtual task do_reset(uvm_sequencer_base sqr = null);
        jtag_transaction txn;
        txn = jtag_transaction::type_id::create("txn_reset");
        start_item(txn, -1, sqr);
        txn.op          = jtag_transaction::JTAG_RESET;
        txn.idle_cycles = 5;
        finish_item(txn);
        `uvm_info(get_type_name(), "JTAG TAP reset completed", UVM_MEDIUM)
    endtask : do_reset

    // ---- IR Scan ----
    virtual task do_ir_scan(bit [4:0] ir, uvm_sequencer_base sqr = null);
        jtag_transaction txn;
        txn = jtag_transaction::type_id::create("txn_ir");
        start_item(txn, -1, sqr);
        txn.op          = jtag_transaction::JTAG_IR_SCAN;
        txn.ir_value    = ir;
        txn.idle_cycles = 1;
        finish_item(txn);
        `uvm_info(get_type_name(), $sformatf("IR scan: 0x%0h", ir), UVM_HIGH)
    endtask : do_ir_scan

    // ---- DR Scan (32-bit interface, backward compatible) ----
    virtual task do_dr_scan(bit [31:0] data, int len, output bit [31:0] rdata,
                            input uvm_sequencer_base sqr = null);
        jtag_transaction txn;
        txn = jtag_transaction::type_id::create("txn_dr");
        start_item(txn, -1, sqr);
        txn.op          = jtag_transaction::JTAG_DR_SCAN;
        txn.dr_value    = {32'b0, data};  // zero-extend to 64 bits
        txn.dr_length   = len;
        txn.idle_cycles = 1;
        finish_item(txn);
        rdata = txn.dr_rdata[31:0];
        `uvm_info(get_type_name(),
                  $sformatf("DR scan: wrote=0x%08h len=%0d read=0x%08h", data, len, rdata),
                  UVM_HIGH)
    endtask : do_dr_scan

    // ---- Idle Cycles ----
    virtual task do_idle(int cycles, uvm_sequencer_base sqr = null);
        jtag_transaction txn;
        txn = jtag_transaction::type_id::create("txn_idle");
        start_item(txn, -1, sqr);
        txn.op          = jtag_transaction::JTAG_IDLE;
        txn.idle_cycles = cycles;
        finish_item(txn);
        `uvm_info(get_type_name(), $sformatf("JTAG idle: %0d cycles", cycles), UVM_HIGH)
    endtask : do_idle

    // ════════════════════════════════════════════════════════════════
    //  Layer 1: DMI (Debug Module Interface) operations
    //  DMI DR format: {addr[6:0], data[31:0], op[1:0]} = 41 bits
    //  Shifted LSB-first: op goes in first, then data, then addr
    // ════════════════════════════════════════════════════════════════

    // ---- Raw DMI DR Scan ----
    // Sends a 41-bit DMI word and returns the response
    virtual task do_dmi_scan(
        bit [6:0]  addr,
        bit [31:0] wdata,
        bit [1:0]  op,
        output bit [31:0] rdata,
        output bit [1:0]  rop,
        input uvm_sequencer_base sqr = null
    );
        jtag_transaction txn;
        txn = jtag_transaction::type_id::create("txn_dmi");
        start_item(txn, -1, sqr);
        txn.op          = jtag_transaction::JTAG_DR_SCAN;
        // Pack DMI word: {addr[6:0], data[31:0], op[1:0]} into 64-bit dr_value
        txn.dr_value    = {23'b0, addr, wdata, op};
        txn.dr_length   = DMI_DR_LEN;
        txn.idle_cycles = 1;
        finish_item(txn);
        // Unpack response: same format
        rop   = txn.dr_rdata[1:0];
        rdata = txn.dr_rdata[33:2];
    endtask : do_dmi_scan

    // ---- DMI Write (high-level, with BUSY retry) ----
    // Per RISC-V Debug Spec §6.1.4: if rop==3 (BUSY), the operation
    // was not performed; the debugger must clear dmireset in dtmcs and retry.
    virtual task dmi_write(bit [6:0] addr, bit [31:0] data,
                           uvm_sequencer_base sqr = null);
        bit [31:0] rdata;
        bit [1:0]  rop;
        int        retries = 0;
        int        max_retries = 5;

        forever begin
            // Select DMI register
            do_ir_scan(IR_DMI, sqr);
            // Send write command
            do_dmi_scan(addr, data, DMI_OP_WRITE, rdata, rop, sqr);
            // Wait for DMI to process
            do_idle(10, sqr);
            // Capture response with NOP (check for errors)
            do_dmi_scan(7'h0, 32'h0, DMI_OP_NOP, rdata, rop, sqr);

            if (rop == 2'b00) begin
                `uvm_info("DMI_WR", $sformatf("DMI write OK: addr=0x%02h data=0x%08h", addr, data), UVM_HIGH)
                return;
            end else if (rop == 2'b11) begin
                retries++;
                if (retries >= max_retries) begin
                    `uvm_error("DMI_WR", $sformatf("DMI write BUSY after %0d retries: addr=0x%02h", max_retries, addr))
                    return;
                end
                `uvm_info("DMI_WR", $sformatf("DMI write BUSY (retry %0d/%0d): addr=0x%02h",
                    retries, max_retries, addr), UVM_MEDIUM)
                // Clear sticky BUSY: write dmireset bit in DTMCS via IR=0x10
                do_ir_scan(5'h10, sqr);
                do_dr_scan(32'h0001_0000, 32, rdata, sqr);  // dtmcs.dmireset=1
                // Wait longer before retry
                do_idle(20 * retries, sqr);
            end else begin
                `uvm_error("DMI_WR", $sformatf("DMI write FAILED: addr=0x%02h data=0x%08h rop=%0b", addr, data, rop))
                return;
            end
        end
    endtask : dmi_write

    // ---- DMI Read (high-level, with BUSY retry) ----
    virtual task dmi_read(bit [6:0] addr, output bit [31:0] rdata,
                          input uvm_sequencer_base sqr = null);
        bit [31:0] dummy;
        bit [1:0]  rop;
        int        retries = 0;
        int        max_retries = 5;

        forever begin
            // Select DMI register
            do_ir_scan(IR_DMI, sqr);
            // Send read command
            do_dmi_scan(addr, 32'h0, DMI_OP_READ, dummy, rop, sqr);
            // Wait for DMI to process
            do_idle(10, sqr);
            // Capture response with NOP
            do_dmi_scan(7'h0, 32'h0, DMI_OP_NOP, rdata, rop, sqr);

            if (rop == 2'b00) begin
                `uvm_info("DMI_RD", $sformatf("DMI read OK: addr=0x%02h -> 0x%08h", addr, rdata), UVM_HIGH)
                return;
            end else if (rop == 2'b11) begin
                retries++;
                if (retries >= max_retries) begin
                    `uvm_error("DMI_RD", $sformatf("DMI read BUSY after %0d retries: addr=0x%02h", max_retries, addr))
                    rdata = 32'h0;
                    return;
                end
                `uvm_info("DMI_RD", $sformatf("DMI read BUSY (retry %0d/%0d): addr=0x%02h",
                    retries, max_retries, addr), UVM_MEDIUM)
                // Clear sticky BUSY: write dmireset bit in DTMCS
                do_ir_scan(5'h10, sqr);
                do_dr_scan(32'h0001_0000, 32, dummy, sqr);
                do_idle(20 * retries, sqr);
            end else begin
                `uvm_error("DMI_RD", $sformatf("DMI read FAILED: addr=0x%02h rop=%0b", addr, rop))
                rdata = 32'h0;
                return;
            end
        end
    endtask : dmi_read

    // ════════════════════════════════════════════════════════════════
    //  Layer 2: SBA (System Bus Access) operations
    //  Uses DMI registers sbcs, sbaddress0, sbdata0 to access
    //  the AXI bus through the Debug Module's System Bus.
    //
    //  JTAG → DMI → Debug Module → SBA → AXI Crossbar → Peripheral
    // ════════════════════════════════════════════════════════════════

    // ---- SBA Initialize ----
    // Activates the Debug Module and configures SBA for 32-bit access
    virtual task sba_init(uvm_sequencer_base sqr = null);
        bit [31:0] sbcs_val;

        // Step 1: Activate Debug Module (dmcontrol.dmactive = 1)
        `uvm_info("SBA", "Initializing SBA: enabling dmactive", UVM_MEDIUM)
        dmi_write(DMI_DMCONTROL, 32'h0000_0001, sqr);

        // Step 2: Read SBCS to verify SBA capabilities
        dmi_read(DMI_SBCS, sbcs_val, sqr);
        `uvm_info("SBA", $sformatf("SBCS capabilities: 0x%08h (32bit=%0b, 64bit=%0b, asize=%0d)",
            sbcs_val, sbcs_val[2], sbcs_val[3], sbcs_val[11:5]), UVM_MEDIUM)

        // Step 3: Configure SBCS for 32-bit access, no auto-increment
        // sbaccess[19:17] = 2 (32-bit), clear errors
        sbcs_val = 32'h0;
        sbcs_val[19:17] = 3'd2;     // sbaccess = 32-bit
        sbcs_val[22]    = 1'b1;     // clear sbbusyerror
        sbcs_val[14:12] = 3'd7;     // clear ALL sberror bits (write 1 to clear)
        dmi_write(DMI_SBCS, sbcs_val, sqr);

        `uvm_info("SBA", "SBA initialized: 32-bit access mode, errors cleared", UVM_MEDIUM)
    endtask : sba_init

    // ---- SBA Write 32-bit ----
    // Writes a 32-bit value to the system bus at the given address
    virtual task sba_write32(bit [31:0] addr, bit [31:0] data,
                             uvm_sequencer_base sqr = null);
        bit [31:0] sbcs_val;

        // Step 0: Reset SBCS — clear sbreadonaddr, clear sberror (W1C=7)
        //   CRITICAL: If a previous sba_read32 left sbreadonaddr=1,
        //   writing SBADDRESS0 would trigger a spurious bus READ.
        sbcs_val = 32'h0;
        sbcs_val[19:17] = 3'd2;     // sbaccess = 32-bit
        sbcs_val[22]    = 1'b1;     // clear sbbusyerror (W1C)
        sbcs_val[14:12] = 3'd7;     // clear ALL sberror bits (W1C)
        // sbreadonaddr = 0 (bit 20 stays 0)
        dmi_write(DMI_SBCS, sbcs_val, sqr);

        // Write address first
        dmi_write(DMI_SBADDRESS0, addr, sqr);
        // Write data → triggers the bus write
        dmi_write(DMI_SBDATA0, data, sqr);

        // Wait for bus transaction to complete
        do_idle(30, sqr);

        // Check SBCS for errors
        dmi_read(DMI_SBCS, sbcs_val, sqr);
        if (sbcs_val[21])
            `uvm_warning("SBA", $sformatf("SBA write: still busy after [0x%08h]=0x%08h", addr, data))
        if (sbcs_val[14:12] != 0)
            `uvm_error("SBA", $sformatf("SBA write ERROR: [0x%08h]=0x%08h sberror=%0d", addr, data, sbcs_val[14:12]))
        else
            `uvm_info("SBA", $sformatf("SBA write OK: [0x%08h] = 0x%08h", addr, data), UVM_MEDIUM)
    endtask : sba_write32

    // ---- SBA Read 32-bit ----
    // Reads a 32-bit value from the system bus at the given address
    virtual task sba_read32(bit [31:0] addr, output bit [31:0] rdata,
                            input uvm_sequencer_base sqr = null);
        bit [31:0] sbcs_val;

        // Step 0: Configure SBCS — sbreadonaddr=1, clear old sberror (W1C=7)
        //   CRITICAL: sberror is sticky! Must clear before each new read.
        sbcs_val = 32'h0;
        sbcs_val[19:17] = 3'd2;     // sbaccess = 32-bit
        sbcs_val[20]    = 1'b1;     // sbreadonaddr = 1
        sbcs_val[22]    = 1'b1;     // clear sbbusyerror (W1C)
        sbcs_val[14:12] = 3'd7;     // clear ALL sberror bits (W1C)
        dmi_write(DMI_SBCS, sbcs_val, sqr);

        // Write address → triggers bus read automatically
        dmi_write(DMI_SBADDRESS0, addr, sqr);

        // Wait for bus transaction to complete
        do_idle(30, sqr);

        // Check SBCS for errors
        dmi_read(DMI_SBCS, sbcs_val, sqr);
        if (sbcs_val[14:12] != 0) begin
            `uvm_error("SBA", $sformatf("SBA read ERROR: [0x%08h] sberror=%0d", addr, sbcs_val[14:12]))
            rdata = 32'h0;
        end else begin
            // Read captured data — only valid if no bus error
            dmi_read(DMI_SBDATA0, rdata, sqr);
            `uvm_info("SBA", $sformatf("SBA read OK: [0x%08h] = 0x%08h", addr, rdata), UVM_MEDIUM)
        end
    endtask : sba_read32

    // ========================== Default body ==========================
    virtual task body();
        `uvm_info(get_type_name(), "jtag_base_seq — default body (no-op)", UVM_LOW)
    endtask : body

endclass : jtag_base_seq

`endif // JTAG_BASE_SEQ_SV
