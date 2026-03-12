`ifndef UART_MONITOR_SV
`define UART_MONITOR_SV

// ============================================================================
// uart_monitor.sv — UART Monitor
// Monitors the TX line (DUT → TB) to capture transmitted data
//
// Timing: At 115200 baud, bit_period = 8680ns, frame = ~87µs
// The sequence MUST wait at least 87µs after THR write for the monitor
// to capture a complete frame.
// ============================================================================

class uart_monitor extends uvm_monitor;

    virtual uart_if vif;
    uart_config     m_cfg;

    uvm_analysis_port #(uart_transaction) ap;

    // Debug counters
    int unsigned total_frames = 0;

    `uvm_component_utils(uart_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "UART virtual interface not found")
        if (!uvm_config_db#(uart_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "UART config not found")
    endfunction

    task run_phase(uvm_phase phase);
        int unsigned bit_period_ns;
        bit_period_ns = m_cfg.get_bit_period_ns();
        `uvm_info("UART_MON", $sformatf(
            "UART Monitor started: baud=%0d, bit_period=%0dns, frame=%0dns, data_bits=%0d",
            m_cfg.baud_rate, bit_period_ns, bit_period_ns * (m_cfg.data_bits + 2),
            m_cfg.data_bits), UVM_LOW)
        monitor_tx_line();
    endtask

    // Report phase — log final statistics
    function void report_phase(uvm_phase phase);
        `uvm_info("UART_MON", $sformatf(
            "UART Monitor Summary: %0d TX frames captured", total_frames), UVM_LOW)
    endfunction

    // Monitor DUT TX output for UART frames
    task monitor_tx_line();
        int unsigned bit_period_ns;
        uart_transaction tr;
        bit [7:0] rx_data;
        bit parity_bit;

        forever begin
            bit_period_ns = m_cfg.get_bit_period_ns();

            // Wait for start bit (falling edge on TX)
            @(negedge vif.tx);

            `uvm_info("UART_MON", $sformatf(
                "Start bit detected @ %0t (TX went LOW)", $realtime), UVM_MEDIUM)

            // Wait half a bit period to sample at center
            #(bit_period_ns / 2 * 1ns);

            // Verify still low (start bit)
            if (vif.tx !== 1'b0) begin
                `uvm_info("UART_MON", "False start bit — TX not low at center", UVM_HIGH)
                continue;
            end

            // Sample data bits
            rx_data = '0;
            for (int i = 0; i < m_cfg.data_bits; i++) begin
                #(bit_period_ns * 1ns);
                rx_data[i] = vif.tx;
            end

            tr = uart_transaction::type_id::create("uart_mon_tr");
            tr.direction = uart_transaction::UART_TX;
            tr.data = rx_data;

            // Optional parity check
            if (m_cfg.parity_en) begin
                #(bit_period_ns * 1ns);
                parity_bit = vif.tx;
                if (m_cfg.parity_even)
                    tr.parity_error = (parity_bit !== ^rx_data);
                else
                    tr.parity_error = (parity_bit !== ~(^rx_data));
            end

            // Stop bit check
            #(bit_period_ns * 1ns);
            tr.frame_error = (vif.tx !== 1'b1);

            total_frames++;

            `uvm_info("UART_MON", $sformatf(
                "Frame #%0d captured @ %0t: data=0x%02h '%c' frame_err=%0b",
                total_frames, $realtime, rx_data,
                (rx_data >= 8'h20 && rx_data <= 8'h7e) ? rx_data : 8'h2e,
                tr.frame_error), UVM_MEDIUM)

            ap.write(tr);
        end
    endtask

endclass : uart_monitor

`endif // UART_MONITOR_SV
