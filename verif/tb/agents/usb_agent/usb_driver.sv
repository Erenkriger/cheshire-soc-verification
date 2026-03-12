// ============================================================================
// usb_driver.sv — USB 1.1 Driver
// Drives USB D+/D- signals to simulate device-side responses.
// Generates USB clock, device connect/disconnect, and basic packets.
// ============================================================================

`ifndef USB_DRIVER_SV
`define USB_DRIVER_SV

class usb_driver extends uvm_driver #(usb_transaction);

    virtual usb_if vif;
    usb_config     m_cfg;

    `uvm_component_utils(usb_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
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

        // Initialize: provide 48 MHz USB clock and hold reset
        vif.usb_rst_n <= 1'b0;
        vif.dp_i      <= 1'b1;  // J state (full-speed idle)
        vif.dm_i      <= 1'b0;

        // Start USB clock generation in background
        fork
            generate_usb_clock();
        join_none

        // Release USB reset after some cycles
        #200ns;
        vif.usb_rst_n <= 1'b1;

        forever begin
            seq_item_port.get_next_item(txn);
            drive_transaction(txn);
            seq_item_port.item_done();
        end
    endtask

    // Generate 48 MHz USB clock
    task generate_usb_clock();
        forever begin
            #(m_cfg.usb_clk_period_ns / 2);
            vif.usb_clk <= 1'b1;
            #(m_cfg.usb_clk_period_ns / 2);
            vif.usb_clk <= 1'b0;
        end
    endtask

    task drive_transaction(usb_transaction txn);
        case (txn.pkt_type)
            usb_transaction::USB_RESET: begin
                `uvm_info(get_type_name(), "USB: Driving bus RESET (SE0)", UVM_MEDIUM)
                vif.dp_i <= 1'b0;
                vif.dm_i <= 1'b0;
                #10_000ns;  // >10ms in real USB, shortened for sim
                vif.dp_i <= 1'b1;
                vif.dm_i <= 1'b0;
            end

            usb_transaction::USB_CONNECT: begin
                `uvm_info(get_type_name(), "USB: Device CONNECT (D+ pull-up)", UVM_MEDIUM)
                vif.dp_i <= 1'b1;
                vif.dm_i <= 1'b0;
                repeat (10) @(posedge vif.clk);
            end

            usb_transaction::USB_DISCONNECT: begin
                `uvm_info(get_type_name(), "USB: Device DISCONNECT (SE0)", UVM_MEDIUM)
                vif.dp_i <= 1'b0;
                vif.dm_i <= 1'b0;
                repeat (10) @(posedge vif.clk);
            end

            usb_transaction::USB_ACK: begin
                // Send ACK PID (0100_1011 NRZI-encoded, simplified)
                drive_sync();
                drive_pid(8'b0100_1011);
                drive_eop();
            end

            usb_transaction::USB_NAK: begin
                drive_sync();
                drive_pid(8'b0101_1010);
                drive_eop();
            end

            usb_transaction::USB_DATA0: begin
                drive_sync();
                drive_pid(8'b1100_0011);  // DATA0 PID
                foreach (txn.payload[i])
                    drive_byte(txn.payload[i]);
                drive_eop();
            end

            usb_transaction::USB_DATA1: begin
                drive_sync();
                drive_pid(8'b1101_0010);  // DATA1 PID
                foreach (txn.payload[i])
                    drive_byte(txn.payload[i]);
                drive_eop();
            end

            usb_transaction::USB_IDLE: begin
                // J state idle
                vif.dp_i <= 1'b1;
                vif.dm_i <= 1'b0;
                repeat (txn.idle_cycles) @(posedge vif.clk);
            end

            default: begin
                repeat (5) @(posedge vif.clk);
            end
        endcase
    endtask

    // Drive SYNC pattern (KJKJKJKK)
    task drive_sync();
        repeat (3) begin
            vif.dp_i <= 1'b0; vif.dm_i <= 1'b1;  // K
            @(posedge vif.clk);
            vif.dp_i <= 1'b1; vif.dm_i <= 1'b0;  // J
            @(posedge vif.clk);
        end
        vif.dp_i <= 1'b0; vif.dm_i <= 1'b1;  // K
        @(posedge vif.clk);
        vif.dp_i <= 1'b0; vif.dm_i <= 1'b1;  // K
        @(posedge vif.clk);
    endtask

    // Drive PID byte (simplified, no bit-stuffing)
    task drive_pid(bit [7:0] pid);
        for (int i = 0; i < 8; i++) begin
            if (pid[i]) begin
                vif.dp_i <= 1'b1; vif.dm_i <= 1'b0;  // J = 1
            end else begin
                vif.dp_i <= 1'b0; vif.dm_i <= 1'b1;  // K = 0
            end
            @(posedge vif.clk);
        end
    endtask

    // Drive data byte
    task drive_byte(bit [7:0] data);
        for (int i = 0; i < 8; i++) begin
            if (data[i]) begin
                vif.dp_i <= 1'b1; vif.dm_i <= 1'b0;
            end else begin
                vif.dp_i <= 1'b0; vif.dm_i <= 1'b1;
            end
            @(posedge vif.clk);
        end
    endtask

    // Drive EOP (SE0 + J)
    task drive_eop();
        vif.dp_i <= 1'b0; vif.dm_i <= 1'b0;  // SE0
        @(posedge vif.clk);
        @(posedge vif.clk);
        vif.dp_i <= 1'b1; vif.dm_i <= 1'b0;  // J (idle)
        @(posedge vif.clk);
    endtask

endclass : usb_driver

`endif // USB_DRIVER_SV
