`ifndef JTAG_DRIVER_SV
`define JTAG_DRIVER_SV

// ============================================================================
// jtag_driver.sv — JTAG TAP Master Driver
// Implements IEEE 1149.1 state machine navigation for IR/DR scan
// ============================================================================

class jtag_driver extends uvm_driver #(jtag_transaction);

    virtual jtag_if vif;
    jtag_config     m_cfg;

    // Driver-side analysis port: broadcasts what was actually driven
    // (with correct IR/DR values from the sequence, not monitor-captured data)
    uvm_analysis_port #(jtag_transaction) drv_ap;

    `uvm_component_utils(jtag_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv_ap = new("drv_ap", this);
        if (!uvm_config_db#(virtual jtag_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "JTAG virtual interface not found in config_db")
        if (!uvm_config_db#(jtag_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "JTAG config not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        jtag_transaction tr;

        // Initialize signals
        vif.tck    = 1'b0;
        vif.tms   <= 1'b1;
        vif.tdi   <= 1'b0;
        vif.trst_n <= 1'b1;

        // Generate JTAG TCK clock (free-running)
        fork
            forever #(m_cfg.tck_period_ns / 2) vif.tck = ~vif.tck;
        join_none

        forever begin
            seq_item_port.get_next_item(tr);
            drive_transaction(tr);
            drv_ap.write(tr);  // Broadcast driven transaction for coverage
            seq_item_port.item_done();
        end
    endtask

    // Drive a JTAG transaction through the TAP state machine
    task drive_transaction(jtag_transaction tr);
        case (tr.op)
            jtag_transaction::JTAG_RESET:   do_reset();
            jtag_transaction::JTAG_IR_SCAN: do_ir_scan(tr);
            jtag_transaction::JTAG_DR_SCAN: do_dr_scan(tr);
            jtag_transaction::JTAG_IDLE:    do_idle(tr.idle_cycles);
        endcase
    endtask

    // TAP Reset: Hold TMS=1 for 5+ TCK cycles → Test-Logic-Reset
    task do_reset();
        vif.trst_n <= 1'b0;
        repeat (5) @(posedge vif.tck);
        vif.trst_n <= 1'b1;
        // Navigate to Run-Test/Idle
        vif.tms <= 1'b0;
        @(posedge vif.tck);
        `uvm_info("JTAG_DRV", "TAP Reset complete", UVM_MEDIUM)
    endtask

    // IR Scan: Navigate Idle → Select-DR → Select-IR → Capture-IR → Shift-IR → Exit1 → Update → Idle
    task do_ir_scan(jtag_transaction tr);
        // Run-Test/Idle → Select-DR-Scan
        vif.tms <= 1'b1; @(posedge vif.tck);
        // Select-DR → Select-IR-Scan
        vif.tms <= 1'b1; @(posedge vif.tck);
        // Select-IR → Capture-IR
        vif.tms <= 1'b0; @(posedge vif.tck);
        // Capture-IR → Shift-IR
        vif.tms <= 1'b0; @(posedge vif.tck);

        // Shift IR bits (LSB first)
        for (int i = 0; i < m_cfg.ir_length; i++) begin
            vif.tdi <= tr.ir_value[i];
            // Last bit: TMS=1 to go to Exit1-IR
            vif.tms <= (i == m_cfg.ir_length - 1) ? 1'b1 : 1'b0;
            @(posedge vif.tck);
        end

        // Exit1-IR → Update-IR
        vif.tms <= 1'b1; @(posedge vif.tck);
        // Update-IR → Run-Test/Idle
        vif.tms <= 1'b0; @(posedge vif.tck);
    endtask

    // DR Scan: Navigate Idle → Select-DR → Capture-DR → Shift-DR → Exit1 → Update → Idle
    task do_dr_scan(jtag_transaction tr);
        // Run-Test/Idle → Select-DR-Scan
        vif.tms <= 1'b1; @(posedge vif.tck);
        // Select-DR → Capture-DR
        vif.tms <= 1'b0; @(posedge vif.tck);
        // Capture-DR → Shift-DR
        vif.tms <= 1'b0; @(posedge vif.tck);

        // Shift DR bits, capture TDO
        tr.dr_rdata = '0;
        for (int i = 0; i < tr.dr_length; i++) begin
            vif.tdi <= tr.dr_value[i];
            vif.tms <= (i == tr.dr_length - 1) ? 1'b1 : 1'b0;
            @(posedge vif.tck);
            #1;  // Let DUT TDO settle (avoid active-region race)
            tr.dr_rdata[i] = vif.tdo;
        end

        // Exit1-DR → Update-DR
        vif.tms <= 1'b1; @(posedge vif.tck);
        // Update-DR → Run-Test/Idle
        vif.tms <= 1'b0; @(posedge vif.tck);
    endtask

    // Idle: Stay in Run-Test/Idle for N cycles
    task do_idle(int unsigned cycles);
        vif.tms <= 1'b0;
        repeat (cycles) @(posedge vif.tck);
    endtask

endclass : jtag_driver

`endif // JTAG_DRIVER_SV
