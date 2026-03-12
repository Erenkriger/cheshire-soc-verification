// ============================================================================
// tb_top.sv — Top-level UVM Testbench
// Instantiates all interfaces, DUT, clock/reset, and wires everything up.
// ============================================================================

`include "uvm_macros.svh"

// Include all interface definitions
`include "axi_if.sv"
`include "apb_if.sv"
`include "spi_if.sv"
`include "uart_if.sv"
`include "i2c_if.sv"
`include "can_if.sv"
`include "jtag_if.sv"

import uvm_pkg::*;
import axi_pkg::*;
import apb_pkg::*;
import spi_pkg::*;
import uart_pkg::*;
import i2c_pkg::*;
import can_pkg::*;
import jtag_pkg::*;
import soc_env_pkg::*;
import soc_seq_pkg::*;
import soc_test_pkg::*;

module tb_top;

    // ═══════════════════════════════════════════
    // Clock & Reset
    // ═══════════════════════════════════════════
    logic clk;
    logic rst_n;

    // System clock: 100 MHz (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset: active-low, held for 100ns
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    // ═══════════════════════════════════════════
    // Interface Instantiation
    // ═══════════════════════════════════════════

    // AXI interface (AMBA4 Interconnect)
    axi_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(64),
        .ID_WIDTH(4)
    ) axi_vif (.aclk(clk), .aresetn(rst_n));

    // APB interface (Peripheral Bus)
    apb_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) apb_vif (.pclk(clk), .presetn(rst_n));

    // UART interface
    uart_if #(
        .DATA_WIDTH(8)
    ) uart_vif (.clk(clk), .rst_n(rst_n));

    // SPI interface
    spi_if #(
        .DATA_WIDTH(8)
    ) spi_vif (.clk(clk), .rst_n(rst_n));

    // I2C interface
    i2c_if i2c_vif (.clk(clk), .rst_n(rst_n));

    // CAN interface
    can_if can_vif (.clk(clk), .rst_n(rst_n));

    // JTAG interface
    jtag_if jtag_vif (.clk(clk), .rst_n(rst_n));

    // ═══════════════════════════════════════════
    // DUT Instantiation
    // ═══════════════════════════════════════════
    soc_top dut (
        .clk        (clk),
        .rst_n      (rst_n),
        // UART
        .uart_rx    (uart_vif.tx),       // TB TX → DUT RX
        .uart_tx    (),                  // DUT TX → monitored
        // SPI
        .spi_sclk   (),
        .spi_mosi   (),
        .spi_miso   (spi_vif.miso),
        .spi_ss_n   (),
        // I2C
        .i2c_scl    (),
        .i2c_sda    (),
        // CAN
        .can_tx     (),
        .can_rx     (can_vif.can_tx),    // TB TX → DUT RX
        // JTAG
        .tck        (jtag_vif.tck),
        .tms        (jtag_vif.tms),
        .tdi        (jtag_vif.tdi),
        .tdo        (jtag_vif.tdo),
        .trst_n     (jtag_vif.trst_n),
        // LVDS
        .lvds_tx_p  (),
        .lvds_tx_n  (),
        .lvds_rx_p  (1'b0),
        .lvds_rx_n  (1'b1),
        // DDR4 PHY
        .ddr4_ck_p  (),
        .ddr4_ck_n  (),
        .ddr4_cke   (),
        .ddr4_cs_n  (),
        .ddr4_ras_n (),
        .ddr4_cas_n (),
        .ddr4_we_n  (),
        .ddr4_addr  (),
        .ddr4_ba    (),
        .ddr4_bg    (),
        .ddr4_dq    (),
        .ddr4_dqs_p (),
        .ddr4_dqs_n (),
        .ddr4_odt   (),
        .ddr4_reset_n()
    );

    // ═══════════════════════════════════════════
    // UVM Config DB — Pass interfaces to agents
    // ═══════════════════════════════════════════
    initial begin
        // AXI
        uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.m_env.m_axi_agent*", "vif", axi_vif);
        // APB
        uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.m_env.m_apb_agent*", "vif", apb_vif);
        // UART
        uvm_config_db#(virtual uart_if)::set(null, "uvm_test_top.m_env.m_uart_agent*", "vif", uart_vif);
        // SPI
        uvm_config_db#(virtual spi_if)::set(null, "uvm_test_top.m_env.m_spi_agent*", "vif", spi_vif);
        // I2C
        uvm_config_db#(virtual i2c_if)::set(null, "uvm_test_top.m_env.m_i2c_agent*", "vif", i2c_vif);
        // CAN
        uvm_config_db#(virtual can_if)::set(null, "uvm_test_top.m_env.m_can_agent*", "vif", can_vif);
        // JTAG
        uvm_config_db#(virtual jtag_if)::set(null, "uvm_test_top.m_env.m_jtag_agent*", "vif", jtag_vif);
    end

    // ═══════════════════════════════════════════
    // UVM Run
    // ═══════════════════════════════════════════
    initial begin
        run_test();
    end

    // ═══════════════════════════════════════════
    // Waveform Dump (for debug)
    // ═══════════════════════════════════════════
    initial begin
        $dumpfile("soc_waves.vcd");
        $dumpvars(0, tb_top);
    end

endmodule : tb_top
