// ============================================================================
// usb_monitor.sv — USB 1.1 Monitor
// Monitors D+/D- bus state transitions for USB activity detection.
// ============================================================================

`ifndef USB_MONITOR_SV
`define USB_MONITOR_SV

class usb_monitor extends uvm_monitor;

    virtual usb_if vif;
    usb_config     m_cfg;

    uvm_analysis_port #(usb_transaction) ap;

    // Statistics
    int unsigned se0_cnt    = 0;   // SE0 (both low) events
    int unsigned j_cnt      = 0;   // J state (D+=1, D-=0)
    int unsigned k_cnt      = 0;   // K state (D+=0, D-=1)
    int unsigned se1_cnt    = 0;   // SE1 (both high, error)
    int unsigned pkt_cnt    = 0;

    `uvm_component_utils(usb_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual usb_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "USB virtual interface not found")
        if (!uvm_config_db#(usb_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "USB config not found")
    endfunction

    task run_phase(uvm_phase phase);
        usb_transaction txn;
        logic prev_dp, prev_dm;
        logic cur_dp, cur_dm;

        prev_dp = 1'b1;
        prev_dm = 1'b0;

        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n) continue;

            // Determine bus state from DUT perspective
            // Use DUT output if OE active, else use TB input
            cur_dp = vif.dp_oe ? vif.dp_o : vif.dp_i;
            cur_dm = vif.dm_oe ? vif.dm_o : vif.dm_i;

            // Detect state change
            if (cur_dp !== prev_dp || cur_dm !== prev_dm) begin
                txn = usb_transaction::type_id::create("usb_mon_txn");
                txn.dp_state  = cur_dp;
                txn.dm_state  = cur_dm;
                txn.timestamp = $time;

                // Classify bus state
                case ({cur_dp, cur_dm})
                    2'b10: begin
                        txn.pkt_type = usb_transaction::USB_IDLE;  // J state
                        j_cnt++;
                    end
                    2'b01: begin
                        txn.pkt_type = usb_transaction::USB_IDLE;  // K state
                        k_cnt++;
                    end
                    2'b00: begin
                        txn.pkt_type = usb_transaction::USB_RESET; // SE0
                        se0_cnt++;
                    end
                    2'b11: begin
                        txn.pkt_type = usb_transaction::USB_IDLE;  // SE1 (error)
                        se1_cnt++;
                        `uvm_warning(get_type_name(), "USB SE1 state detected (both D+/D- high)")
                    end
                endcase

                ap.write(txn);
                pkt_cnt++;
            end

            prev_dp = cur_dp;
            prev_dm = cur_dm;
        end
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf(
            "USB Monitor Summary: J=%0d  K=%0d  SE0=%0d  SE1=%0d  total_events=%0d",
            j_cnt, k_cnt, se0_cnt, se1_cnt, pkt_cnt), UVM_LOW)
    endfunction

endclass : usb_monitor

`endif // USB_MONITOR_SV
