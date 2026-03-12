`ifndef UART_DRIVER_SV
`define UART_DRIVER_SV

// ============================================================================
// uart_driver.sv — UART Driver
// Drives the RX line (TB → DUT) with proper UART frame timing
// ============================================================================

class uart_driver extends uvm_driver #(uart_transaction);

    virtual uart_if vif;
    uart_config     m_cfg;

    `uvm_component_utils(uart_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "UART virtual interface not found")
        if (!uvm_config_db#(uart_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "UART config not found")
    endfunction

    task run_phase(uvm_phase phase);
        uart_transaction tr;
        // Idle state: RX line high
        vif.rx    <= 1'b1;
        vif.cts_n <= 1'b0;  // Clear To Send (active low = ready)
        vif.dsr_n <= 1'b0;
        vif.dcd_n <= 1'b0;
        vif.rin_n <= 1'b1;

        forever begin
            seq_item_port.get_next_item(tr);
            send_frame(tr);
            seq_item_port.item_done();
        end
    endtask

    // Send a UART frame on the RX pin (TB → DUT)
    task send_frame(uart_transaction tr);
        int unsigned bit_period_ns = m_cfg.get_bit_period_ns();
        bit parity_bit;

        `uvm_info("UART_DRV", $sformatf("Sending byte 0x%02h", tr.data), UVM_HIGH)

        // Start bit (low)
        vif.rx <= 1'b0;
        #(bit_period_ns * 1ns);

        // Data bits (LSB first)
        for (int i = 0; i < m_cfg.data_bits; i++) begin
            vif.rx <= tr.data[i];
            #(bit_period_ns * 1ns);
        end

        // Optional parity bit
        if (m_cfg.parity_en) begin
            parity_bit = ^tr.data;
            if (m_cfg.parity_even)
                vif.rx <= parity_bit;
            else
                vif.rx <= ~parity_bit;
            #(bit_period_ns * 1ns);
        end

        // Stop bit(s) (high)
        vif.rx <= 1'b1;
        repeat (m_cfg.stop_bits) #(bit_period_ns * 1ns);
    endtask

endclass : uart_driver

`endif // UART_DRIVER_SV
