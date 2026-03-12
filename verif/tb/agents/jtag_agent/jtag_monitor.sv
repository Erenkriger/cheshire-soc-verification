`ifndef JTAG_MONITOR_SV
`define JTAG_MONITOR_SV

// ============================================================================
// jtag_monitor.sv — JTAG TAP Monitor (Passive)
// Observes TAP state transitions and captures IR/DR scan data
// ============================================================================

class jtag_monitor extends uvm_monitor;

    virtual jtag_if vif;
    jtag_config     m_cfg;

    uvm_analysis_port #(jtag_transaction) ap;

    `uvm_component_utils(jtag_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual jtag_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "JTAG virtual interface not found in config_db")
        if (!uvm_config_db#(jtag_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "JTAG config not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        monitor_tap();
    endtask

    // Simple TAP state machine tracker
    task monitor_tap();
        typedef enum {
            TLR, RTI, SELECT_DR, CAPTURE_DR, SHIFT_DR, EXIT1_DR, PAUSE_DR, EXIT2_DR, UPDATE_DR,
            SELECT_IR, CAPTURE_IR, SHIFT_IR, EXIT1_IR, PAUSE_IR, EXIT2_IR, UPDATE_IR
        } tap_state_e;

        tap_state_e state = TLR;
        jtag_transaction tr;
        bit [63:0] shift_data;
        int shift_count;

        forever begin
            @(posedge vif.tck);
            #1;  // Let DUT signals settle (avoid active-region race)

            if (!vif.trst_n) begin
                state = TLR;
                continue;
            end

            case (state)
                TLR:        state = vif.tms ? TLR : RTI;
                RTI:        state = vif.tms ? SELECT_DR : RTI;
                SELECT_DR:  state = vif.tms ? SELECT_IR : CAPTURE_DR;
                CAPTURE_DR: begin
                    state = vif.tms ? EXIT1_DR : SHIFT_DR;
                    shift_data = '0;
                    shift_count = 0;
                end
                SHIFT_DR: begin
                    shift_data[shift_count] = vif.tdo;
                    shift_count++;
                    state = vif.tms ? EXIT1_DR : SHIFT_DR;
                end
                EXIT1_DR:   state = vif.tms ? UPDATE_DR : PAUSE_DR;
                PAUSE_DR:   state = vif.tms ? EXIT2_DR : PAUSE_DR;
                EXIT2_DR:   state = vif.tms ? UPDATE_DR : SHIFT_DR;
                UPDATE_DR: begin
                    state = vif.tms ? SELECT_DR : RTI;
                    // Broadcast captured DR transaction
                    tr = jtag_transaction::type_id::create("jtag_mon_tr");
                    tr.op = jtag_transaction::JTAG_DR_SCAN;
                    tr.dr_rdata = shift_data[31:0];
                    tr.dr_length = shift_count;
                    ap.write(tr);
                end
                SELECT_IR:  state = vif.tms ? TLR : CAPTURE_IR;
                CAPTURE_IR: begin
                    state = vif.tms ? EXIT1_IR : SHIFT_IR;
                    shift_data = '0;
                    shift_count = 0;
                end
                SHIFT_IR: begin
                    shift_data[shift_count] = vif.tdo;
                    shift_count++;
                    state = vif.tms ? EXIT1_IR : SHIFT_IR;
                end
                EXIT1_IR:   state = vif.tms ? UPDATE_IR : PAUSE_IR;
                PAUSE_IR:   state = vif.tms ? EXIT2_IR : PAUSE_IR;
                EXIT2_IR:   state = vif.tms ? UPDATE_IR : SHIFT_IR;
                UPDATE_IR: begin
                    state = vif.tms ? SELECT_DR : RTI;
                    tr = jtag_transaction::type_id::create("jtag_mon_tr");
                    tr.op = jtag_transaction::JTAG_IR_SCAN;
                    tr.ir_value = shift_data[4:0];
                    ap.write(tr);
                end
            endcase
        end
    endtask

endclass : jtag_monitor

`endif // JTAG_MONITOR_SV
