`ifndef I2C_DRIVER_SV
`define I2C_DRIVER_SV

// ============================================================================
// i2c_driver.sv — I2C Slave Driver
// Since the DUT is the I2C master, this driver acts as a slave device.
// Monitors for START, receives address, sends ACK/NACK, handles data phases.
// ============================================================================

class i2c_driver extends uvm_driver #(i2c_transaction);

    virtual i2c_if vif;
    i2c_config     m_cfg;

    `uvm_component_utils(i2c_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual i2c_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "I2C virtual interface not found in config_db")
        if (!uvm_config_db#(i2c_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "I2C config not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        i2c_transaction tr;

        // Release bus (no pull-down)
        vif.tb_sda_pull <= 1'b0;
        vif.tb_scl_pull <= 1'b0;

        forever begin
            seq_item_port.get_next_item(tr);
            handle_slave_transaction(tr);
            seq_item_port.item_done();
        end
    endtask

    // Handle a complete I2C slave transaction
    // Includes timeout guard: if DUT I2C master never generates START,
    // the transaction completes with a warning instead of hanging.
    task handle_slave_transaction(i2c_transaction tr);
        bit timed_out = 0;

        if (m_cfg.driver_timeout > 0) begin
            fork
                begin : i2c_actual_handle
                    do_slave_transaction(tr);
                end
                begin : i2c_timeout_guard
                    #(m_cfg.driver_timeout);
                    timed_out = 1;
                end
            join_any
            disable i2c_actual_handle;
            disable i2c_timeout_guard;

            if (timed_out) begin
                `uvm_warning("I2C_DRV", $sformatf(
                    "Slave transaction timeout (%0t) - DUT I2C master did not generate START. Ensure I2C controller is programmed via CSR before running I2C slave tests.",
                    m_cfg.driver_timeout))
            end
        end else begin
            do_slave_transaction(tr);
        end
    endtask : handle_slave_transaction

    // Actual slave transaction logic (extracted for timeout wrapping)
    task do_slave_transaction(i2c_transaction tr);
        bit [7:0] addr_byte;
        bit       rw_bit;
        bit       addr_match;

        `uvm_info("I2C_DRV", $sformatf("Slave ready (addr=0x%02h), waiting for START",
            m_cfg.slave_address), UVM_HIGH)

        // Wait for START condition: SDA falls while SCL is high
        detect_start();

        // Receive address byte (7-bit addr + R/W bit)
        receive_byte(addr_byte);
        rw_bit    = addr_byte[0];
        addr_match = (addr_byte[7:1] == m_cfg.slave_address);

        `uvm_info("I2C_DRV", $sformatf("Received addr=0x%02h, R/W=%0b, match=%0b",
            addr_byte[7:1], rw_bit, addr_match), UVM_MEDIUM)

        // Send ACK or NACK on address
        if (addr_match && !tr.nack_on_addr) begin
            send_ack();
            tr.ack_received = 1'b1;
        end else begin
            send_nack();
            tr.ack_received = 1'b0;
            `uvm_info("I2C_DRV", "Address NACK sent", UVM_MEDIUM)
            return;
        end

        // Data phase
        if (rw_bit == i2c_transaction::I2C_WRITE) begin
            // Master writes, slave receives
            handle_slave_write(tr);
        end else begin
            // Master reads, slave transmits
            handle_slave_read(tr);
        end
    endtask : do_slave_transaction

    // Detect I2C START condition (SDA falling while SCL high)
    task detect_start();
        forever begin
            @(negedge vif.sda_bus);
            if (vif.scl_bus === 1'b1) begin
                `uvm_info("I2C_DRV", "START condition detected", UVM_HIGH)
                return;
            end
        end
    endtask

    // Receive a byte from the bus (MSB first), returns 8 bits
    task receive_byte(output bit [7:0] data);
        data = '0;
        for (int i = 7; i >= 0; i--) begin
            @(posedge vif.scl_bus);
            data[i] = vif.sda_bus;

            // Optional clock stretching
            if (m_cfg.stretch_en && i == 4) begin
                vif.tb_scl_pull <= 1'b1;
                #(m_cfg.get_scl_half_period_ns() * 1ns);
                vif.tb_scl_pull <= 1'b0;
            end

            @(negedge vif.scl_bus);
        end
    endtask

    // Send ACK (pull SDA low during 9th clock)
    task send_ack();
        vif.tb_sda_pull <= 1'b1;   // Pull SDA low = ACK
        @(posedge vif.scl_bus);
        @(negedge vif.scl_bus);
        vif.tb_sda_pull <= 1'b0;   // Release SDA
    endtask

    // Send NACK (leave SDA high during 9th clock)
    task send_nack();
        vif.tb_sda_pull <= 1'b0;   // SDA stays high = NACK
        @(posedge vif.scl_bus);
        @(negedge vif.scl_bus);
    endtask

    // Handle master-write (slave receives data bytes)
    task handle_slave_write(i2c_transaction tr);
        bit [7:0] rx_data;
        bit [7:0] data_queue[$];

        for (int byte_idx = 0; byte_idx < tr.data.size(); byte_idx++) begin
            // Check for repeated START or STOP before each byte
            fork
                begin : recv_block
                    receive_byte(rx_data);
                    data_queue.push_back(rx_data);
                    send_ack();
                end
                begin : stop_detect
                    detect_stop_condition();
                    `uvm_info("I2C_DRV", "STOP detected during write", UVM_MEDIUM)
                end
            join_any
            disable fork;

            // If STOP was detected, break out
            if (data_queue.size() <= byte_idx) break;
        end

        // Update transaction with received data
        tr.data = new[data_queue.size()];
        foreach (data_queue[i]) tr.data[i] = data_queue[i];

        `uvm_info("I2C_DRV", $sformatf("Slave write complete: %0d bytes received",
            data_queue.size()), UVM_MEDIUM)
    endtask

    // Handle master-read (slave transmits data bytes)
    task handle_slave_read(i2c_transaction tr);
        for (int byte_idx = 0; byte_idx < tr.data.size(); byte_idx++) begin
            send_byte(tr.data[byte_idx]);

            // Wait for master ACK/NACK
            @(posedge vif.scl_bus);
            if (vif.sda_bus === 1'b1) begin
                // Master NACK — end of read
                `uvm_info("I2C_DRV", $sformatf(
                    "Master NACK after byte %0d, read complete", byte_idx), UVM_MEDIUM)
                @(negedge vif.scl_bus);
                break;
            end
            @(negedge vif.scl_bus);
        end
    endtask

    // Send a byte on SDA (MSB first)
    task send_byte(bit [7:0] data);
        for (int i = 7; i >= 0; i--) begin
            // Drive SDA on SCL low
            vif.tb_sda_pull <= ~data[i];  // Pull low if bit=0, release if bit=1
            @(posedge vif.scl_bus);
            @(negedge vif.scl_bus);
        end
        // Release SDA for ACK/NACK
        vif.tb_sda_pull <= 1'b0;
    endtask

    // Detect STOP condition (SDA rising while SCL high)
    task detect_stop_condition();
        forever begin
            @(posedge vif.sda_bus);
            if (vif.scl_bus === 1'b1) begin
                return;
            end
        end
    endtask

endclass : i2c_driver

`endif // I2C_DRIVER_SV
