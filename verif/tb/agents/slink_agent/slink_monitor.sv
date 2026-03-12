// ============================================================================
// slink_monitor.sv — Serial Link Monitor
// Monitors both TX (DUT→external) and RX (external→DUT) data lanes.
// ============================================================================

`ifndef SLINK_MONITOR_SV
`define SLINK_MONITOR_SV

class slink_monitor extends uvm_monitor;

    virtual slink_if vif;
    slink_config     m_cfg;

    uvm_analysis_port #(slink_transaction) ap;

    int unsigned tx_beat_cnt = 0;
    int unsigned rx_beat_cnt = 0;

    `uvm_component_utils(slink_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual slink_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Serial Link virtual interface not found")
        if (!uvm_config_db#(slink_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "Serial Link config not found")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            monitor_tx_channel();
            monitor_rx_channel();
        join
    endtask

    // Monitor DUT output (TX path: DUT → external)
    task monitor_tx_channel();
        slink_transaction txn;
        logic [3:0] prev_data;

        prev_data = '0;
        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.data_o[0] !== prev_data) begin
                txn = slink_transaction::type_id::create("slink_tx_txn");
                txn.op        = slink_transaction::SLINK_TX;
                txn.lane_data = vif.data_o[0];
                txn.channel   = 0;
                txn.timestamp = $time;
                txn.num_beats = 1;
                ap.write(txn);
                tx_beat_cnt++;
            end
            prev_data = vif.data_o[0];
        end
    endtask

    // Monitor external input (RX path: external → DUT)
    task monitor_rx_channel();
        slink_transaction txn;
        logic [3:0] prev_data;

        prev_data = '0;
        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.data_i[0] !== prev_data) begin
                txn = slink_transaction::type_id::create("slink_rx_txn");
                txn.op        = slink_transaction::SLINK_RX;
                txn.lane_data = vif.data_i[0];
                txn.channel   = 0;
                txn.timestamp = $time;
                txn.num_beats = 1;
                ap.write(txn);
                rx_beat_cnt++;
            end
            prev_data = vif.data_i[0];
        end
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf(
            "Serial Link Monitor Summary: TX beats=%0d  RX beats=%0d",
            tx_beat_cnt, rx_beat_cnt), UVM_LOW)
    endfunction

endclass : slink_monitor

`endif // SLINK_MONITOR_SV
