// ============================================================================
// vga_monitor.sv — VGA Monitor (Passive)
// Monitors hsync/vsync transitions and captures pixel data during
// active display region. Tracks frame count and sync timing.
// ============================================================================

`ifndef VGA_MONITOR_SV
`define VGA_MONITOR_SV

class vga_monitor extends uvm_monitor;

    virtual vga_if   vif;
    vga_config       m_cfg;

    uvm_analysis_port #(vga_transaction) ap;

    // Statistics
    int unsigned hsync_cnt   = 0;
    int unsigned vsync_cnt   = 0;
    int unsigned pixel_cnt   = 0;
    int unsigned frame_cnt   = 0;
    int unsigned active_px   = 0;

    `uvm_component_utils(vga_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual vga_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "VGA virtual interface not found")
        if (!uvm_config_db#(vga_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "VGA config not found")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            monitor_sync();
            monitor_pixels();
        join
    endtask

    // Track sync edges for frame/line counting
    task monitor_sync();
        logic prev_hsync, prev_vsync;
        prev_hsync = 1'b0;
        prev_vsync = 1'b0;

        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n) continue;

            // Detect HSYNC rising edge
            if (vif.hsync && !prev_hsync) begin
                vga_transaction txn;
                txn = vga_transaction::type_id::create("vga_hsync_txn");
                txn.event_type = vga_transaction::VGA_HSYNC;
                txn.hsync      = 1'b1;
                txn.vsync      = vif.vsync;
                txn.timestamp  = $time;
                txn.frame_num  = frame_cnt;
                ap.write(txn);
                hsync_cnt++;
            end

            // Detect VSYNC rising edge (new frame)
            if (vif.vsync && !prev_vsync) begin
                vga_transaction txn;
                txn = vga_transaction::type_id::create("vga_vsync_txn");
                txn.event_type = vga_transaction::VGA_VSYNC;
                txn.hsync      = vif.hsync;
                txn.vsync      = 1'b1;
                txn.timestamp  = $time;
                txn.frame_num  = frame_cnt;
                ap.write(txn);
                vsync_cnt++;
                frame_cnt++;
                `uvm_info(get_type_name(), $sformatf(
                    "VGA Frame %0d complete (active pixels: %0d)",
                    frame_cnt - 1, active_px), UVM_MEDIUM)
                active_px = 0;
            end

            prev_hsync = vif.hsync;
            prev_vsync = vif.vsync;
        end
    endtask

    // Monitor active pixel data
    task monitor_pixels();
        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n) continue;

            // Check for non-zero pixel (active display)
            if (|vif.red || |vif.green || |vif.blue) begin
                vga_transaction txn;
                txn = vga_transaction::type_id::create("vga_pixel_txn");
                txn.event_type = vga_transaction::VGA_PIXEL;
                txn.red        = vif.red;
                txn.green      = vif.green;
                txn.blue       = vif.blue;
                txn.hsync      = vif.hsync;
                txn.vsync      = vif.vsync;
                txn.timestamp  = $time;
                txn.frame_num  = frame_cnt;
                ap.write(txn);
                pixel_cnt++;
                active_px++;
            end
        end
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf(
            "VGA Monitor Summary: frames=%0d  hsyncs=%0d  vsyncs=%0d  active_pixels=%0d",
            frame_cnt, hsync_cnt, vsync_cnt, pixel_cnt), UVM_LOW)
    endfunction

endclass : vga_monitor

`endif // VGA_MONITOR_SV
