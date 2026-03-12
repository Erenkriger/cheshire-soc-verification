`ifndef I2C_MONITOR_SV
`define I2C_MONITOR_SV

// ============================================================================
// i2c_monitor.sv — I2C Bus Monitor (Passive)
// Detects START/STOP conditions, captures address + data, reports transactions
// ============================================================================

class i2c_monitor extends uvm_monitor;

    virtual i2c_if vif;
    i2c_config     m_cfg;

    uvm_analysis_port #(i2c_transaction) ap;

    `uvm_component_utils(i2c_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual i2c_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "I2C virtual interface not found in config_db")
        if (!uvm_config_db#(i2c_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "I2C config not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            monitor_i2c_transfer();
        end
    endtask

    // Monitor a complete I2C transaction
    task monitor_i2c_transfer();
        i2c_transaction tr;
        bit [7:0] addr_byte;
        bit [7:0] data_byte;
        bit [7:0] data_queue[$];
        bit       rw_bit;
        bit       ack_bit;
        bit       stop_seen;

        // Wait for START condition
        wait_for_start();

        tr = i2c_transaction::type_id::create("i2c_mon_tr");
        tr.start_detected = 1'b1;

        // Capture address byte (7 addr bits + R/W)
        capture_byte(addr_byte);
        tr.slave_addr = addr_byte[7:1];
        rw_bit        = addr_byte[0];
        tr.op = rw_bit ? i2c_transaction::I2C_READ : i2c_transaction::I2C_WRITE;

        `uvm_info("I2C_MON", $sformatf("Address phase: addr=0x%02h, R/W=%0b",
            tr.slave_addr, rw_bit), UVM_HIGH)

        // Capture ACK/NACK for address
        capture_ack(ack_bit);
        tr.ack_received = ~ack_bit;  // ACK=0 (pulled low), NACK=1

        if (ack_bit) begin
            // NACK on address — wait for STOP and report
            tr.nack_on_addr = 1'b1;
            `uvm_info("I2C_MON", "Address NACK detected", UVM_MEDIUM)
            wait_for_stop();
            tr.stop_detected = 1'b1;
            ap.write(tr);
            return;
        end

        // Data phase — capture bytes until STOP or repeated START
        stop_seen = 1'b0;
        while (!stop_seen) begin
            fork
                begin : data_capture
                    capture_byte(data_byte);
                    data_queue.push_back(data_byte);
                    capture_ack(ack_bit);
                    // Master NACK during read means last byte
                    if (rw_bit && ack_bit) stop_seen = 1'b1;
                end
                begin : stop_watch
                    wait_for_stop();
                    stop_seen = 1'b1;
                end
            join_any
            disable fork;
        end

        // Populate transaction
        tr.data = new[data_queue.size()];
        foreach (data_queue[i]) tr.data[i] = data_queue[i];
        tr.stop_detected = 1'b1;

        `uvm_info("I2C_MON", $sformatf(
            "Transfer complete: addr=0x%02h, op=%s, %0d bytes",
            tr.slave_addr, tr.op.name(), data_queue.size()), UVM_MEDIUM)

        ap.write(tr);
    endtask

    // Wait for START condition: SDA falls while SCL is high
    task wait_for_start();
        forever begin
            @(negedge vif.sda_bus);
            if (vif.scl_bus === 1'b1) begin
                `uvm_info("I2C_MON", "START condition detected", UVM_HIGH)
                return;
            end
        end
    endtask

    // Wait for STOP condition: SDA rises while SCL is high
    task wait_for_stop();
        forever begin
            @(posedge vif.sda_bus);
            if (vif.scl_bus === 1'b1) begin
                `uvm_info("I2C_MON", "STOP condition detected", UVM_HIGH)
                return;
            end
        end
    endtask

    // Capture 8 bits from SDA (MSB first), sampled on SCL rising edge
    task capture_byte(output bit [7:0] data);
        data = '0;
        for (int i = 7; i >= 0; i--) begin
            @(posedge vif.scl_bus);
            data[i] = vif.sda_bus;
            @(negedge vif.scl_bus);
        end
    endtask

    // Capture ACK/NACK bit (9th clock cycle)
    task capture_ack(output bit ack);
        @(posedge vif.scl_bus);
        ack = vif.sda_bus;   // 0 = ACK, 1 = NACK
        @(negedge vif.scl_bus);
    endtask

endclass : i2c_monitor

`endif // I2C_MONITOR_SV
