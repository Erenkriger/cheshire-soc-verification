`ifndef CHS_AXI_MONITOR_SV
`define CHS_AXI_MONITOR_SV

// ============================================================================
// chs_axi_monitor.sv — AXI4 UVM Passive Monitor for Cheshire SoC
//
// Passively observes the AXI LLC/DRAM port and reconstructs full
// transactions (write = AW+W+B, read = AR+R). Emits completed
// transactions via analysis port to scoreboard and coverage.
//
// Handles:
//   - AW/W interleaving (W can arrive before AW in some cases)
//   - Multiple outstanding transactions (tracked by ID)
//   - Latency measurement (start_time to end_time)
// ============================================================================

class chs_axi_monitor extends uvm_monitor;

    `uvm_component_utils(chs_axi_monitor)

    virtual chs_axi_if vif;
    uvm_analysis_port #(chs_axi_seq_item) ap;

    // Pending transaction tracking
    chs_axi_seq_item pending_writes[int];   // Keyed by ID
    chs_axi_seq_item pending_reads[int];    // Keyed by ID

    // W-data accumulator (for cases where W arrives before AW)
    bit [63:0]  w_data_q[$];
    bit [7:0]   w_strb_q[$];
    bit         w_last_seen;

    // Statistics
    int unsigned write_count;
    int unsigned read_count;
    int unsigned total_aw_handshakes;
    int unsigned total_w_handshakes;
    int unsigned total_b_handshakes;
    int unsigned total_ar_handshakes;
    int unsigned total_r_handshakes;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        write_count = 0;
        read_count  = 0;
        total_aw_handshakes = 0;
        total_w_handshakes  = 0;
        total_b_handshakes  = 0;
        total_ar_handshakes = 0;
        total_r_handshakes  = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);

        if (!uvm_config_db#(virtual chs_axi_if)::get(this, "", "vif", vif))
            `uvm_fatal("AXI_MON", "Virtual interface 'vif' not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        // Wait for reset deassertion
        @(posedge vif.aresetn);
        `uvm_info("AXI_MON", "Reset deasserted — starting AXI monitoring", UVM_LOW)

        fork
            monitor_aw_channel();
            monitor_w_channel();
            monitor_b_channel();
            monitor_ar_channel();
            monitor_r_channel();
        join
    endtask

    // ═══════════════════════════════════════════
    // Write Address Channel Monitor
    // ═══════════════════════════════════════════
    task monitor_aw_channel();
        forever begin
            @(posedge vif.aclk);
            if (vif.aresetn && vif.awvalid && vif.awready) begin
                chs_axi_seq_item txn;
                txn = chs_axi_seq_item::type_id::create("aw_txn");
                txn.rw         = chs_axi_seq_item::AXI_WRITE;
                txn.addr       = vif.awaddr;
                txn.id         = vif.awid;
                txn.len        = vif.awlen;
                txn.size       = vif.awsize;
                txn.burst      = vif.awburst;
                txn.lock       = vif.awlock;
                txn.cache      = vif.awcache;
                txn.prot       = vif.awprot;
                txn.qos        = vif.awqos;
                txn.atop       = vif.awatop;
                txn.start_time = $time;
                txn.wdata      = new[txn.len + 1];
                txn.wstrb      = new[txn.len + 1];

                pending_writes[txn.id] = txn;
                total_aw_handshakes++;

                `uvm_info("AXI_MON", $sformatf("AW handshake: addr=0x%012h id=%0d len=%0d size=%0d burst=%0d atop=0x%02h",
                          txn.addr, txn.id, txn.len, txn.size, txn.burst, txn.atop), UVM_HIGH)
            end
        end
    endtask

    // ═══════════════════════════════════════════
    // Write Data Channel Monitor
    // ═══════════════════════════════════════════
    task monitor_w_channel();
        int beat_idx = 0;
        forever begin
            @(posedge vif.aclk);
            if (vif.aresetn && vif.wvalid && vif.wready) begin
                w_data_q.push_back(vif.wdata);
                w_strb_q.push_back(vif.wstrb);
                total_w_handshakes++;

                if (vif.wlast) begin
                    // Try to match with pending AW
                    foreach (pending_writes[id]) begin
                        chs_axi_seq_item txn = pending_writes[id];
                        if (txn.wdata.size() > 0 && txn.wdata[0] === '0) begin
                            // This txn hasn't had data assigned yet
                            for (int i = 0; i < w_data_q.size() && i < txn.wdata.size(); i++) begin
                                txn.wdata[i] = w_data_q[i];
                                txn.wstrb[i] = w_strb_q[i];
                            end
                            break;
                        end
                    end
                    w_data_q.delete();
                    w_strb_q.delete();
                end
            end
        end
    endtask

    // ═══════════════════════════════════════════
    // Write Response Channel Monitor
    // ═══════════════════════════════════════════
    task monitor_b_channel();
        forever begin
            @(posedge vif.aclk);
            if (vif.aresetn && vif.bvalid && vif.bready) begin
                total_b_handshakes++;

                if (pending_writes.exists(vif.bid)) begin
                    chs_axi_seq_item txn = pending_writes[vif.bid];
                    txn.resp     = vif.bresp;
                    txn.end_time = $time;
                    txn.latency_cycles = (txn.end_time - txn.start_time) / (20); // Assuming 20ns period
                    pending_writes.delete(vif.bid);
                    write_count++;
                    ap.write(txn);

                    `uvm_info("AXI_MON", $sformatf("W COMPLETE: %s", txn.convert2string()), UVM_MEDIUM)
                end else begin
                    `uvm_warning("AXI_MON", $sformatf("B response with no matching AW (bid=%0d bresp=%0d)", vif.bid, vif.bresp))
                end
            end
        end
    endtask

    // ═══════════════════════════════════════════
    // Read Address Channel Monitor
    // ═══════════════════════════════════════════
    task monitor_ar_channel();
        forever begin
            @(posedge vif.aclk);
            if (vif.aresetn && vif.arvalid && vif.arready) begin
                chs_axi_seq_item txn;
                txn = chs_axi_seq_item::type_id::create("ar_txn");
                txn.rw         = chs_axi_seq_item::AXI_READ;
                txn.addr       = vif.araddr;
                txn.id         = vif.arid;
                txn.len        = vif.arlen;
                txn.size       = vif.arsize;
                txn.burst      = vif.arburst;
                txn.lock       = vif.arlock;
                txn.cache      = vif.arcache;
                txn.prot       = vif.arprot;
                txn.qos        = vif.arqos;
                txn.start_time = $time;
                txn.rdata      = new[txn.len + 1];

                pending_reads[txn.id] = txn;
                total_ar_handshakes++;

                `uvm_info("AXI_MON", $sformatf("AR handshake: addr=0x%012h id=%0d len=%0d size=%0d burst=%0d",
                          txn.addr, txn.id, txn.len, txn.size, txn.burst), UVM_HIGH)
            end
        end
    endtask

    // ═══════════════════════════════════════════
    // Read Data Channel Monitor
    // ═══════════════════════════════════════════
    task monitor_r_channel();
        bit [63:0] rd_data_q[$];
        bit [1:0]  rd_resp_q[$];
        bit [7:0]  rd_id;

        forever begin
            @(posedge vif.aclk);
            if (vif.aresetn && vif.rvalid && vif.rready) begin
                total_r_handshakes++;
                rd_id = vif.rid;
                rd_data_q.push_back(vif.rdata);
                rd_resp_q.push_back(vif.rresp);

                if (vif.rlast) begin
                    if (pending_reads.exists(rd_id)) begin
                        chs_axi_seq_item txn = pending_reads[rd_id];
                        txn.rdata = new[rd_data_q.size()];
                        for (int i = 0; i < rd_data_q.size(); i++)
                            txn.rdata[i] = rd_data_q[i];
                        txn.resp     = rd_resp_q[rd_resp_q.size()-1];
                        txn.end_time = $time;
                        txn.latency_cycles = (txn.end_time - txn.start_time) / (20);
                        txn.len = rd_data_q.size() - 1;
                        pending_reads.delete(rd_id);
                        read_count++;
                        ap.write(txn);

                        `uvm_info("AXI_MON", $sformatf("R COMPLETE: %s", txn.convert2string()), UVM_MEDIUM)
                    end else begin
                        // No matching AR — could be AXI reordering; create standalone
                        chs_axi_seq_item txn = chs_axi_seq_item::type_id::create("rd_orphan");
                        txn.rw   = chs_axi_seq_item::AXI_READ;
                        txn.id   = rd_id;
                        txn.len  = rd_data_q.size() - 1;
                        txn.rdata = new[rd_data_q.size()];
                        for (int i = 0; i < rd_data_q.size(); i++)
                            txn.rdata[i] = rd_data_q[i];
                        txn.resp = rd_resp_q[rd_resp_q.size()-1];
                        txn.end_time = $time;
                        read_count++;
                        ap.write(txn);
                    end
                    rd_data_q.delete();
                    rd_resp_q.delete();
                end
            end
        end
    endtask

    // ═══════════════════════════════════════════
    // Report Phase
    // ═══════════════════════════════════════════
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("AXI_MON", "════════════════════════════════════════════", UVM_NONE)
        `uvm_info("AXI_MON", "  AXI LLC Monitor Statistics", UVM_NONE)
        `uvm_info("AXI_MON", "════════════════════════════════════════════", UVM_NONE)
        `uvm_info("AXI_MON", $sformatf("  Write transactions : %0d", write_count), UVM_NONE)
        `uvm_info("AXI_MON", $sformatf("  Read transactions  : %0d", read_count), UVM_NONE)
        `uvm_info("AXI_MON", $sformatf("  AW handshakes      : %0d", total_aw_handshakes), UVM_NONE)
        `uvm_info("AXI_MON", $sformatf("  W  handshakes      : %0d", total_w_handshakes), UVM_NONE)
        `uvm_info("AXI_MON", $sformatf("  B  handshakes      : %0d", total_b_handshakes), UVM_NONE)
        `uvm_info("AXI_MON", $sformatf("  AR handshakes      : %0d", total_ar_handshakes), UVM_NONE)
        `uvm_info("AXI_MON", $sformatf("  R  handshakes      : %0d", total_r_handshakes), UVM_NONE)
        if (pending_writes.size() > 0)
            `uvm_warning("AXI_MON", $sformatf("  %0d pending writes at end of sim!", pending_writes.size()))
        if (pending_reads.size() > 0)
            `uvm_warning("AXI_MON", $sformatf("  %0d pending reads at end of sim!", pending_reads.size()))
        `uvm_info("AXI_MON", "════════════════════════════════════════════", UVM_NONE)
    endfunction

endclass : chs_axi_monitor

`endif // CHS_AXI_MONITOR_SV
