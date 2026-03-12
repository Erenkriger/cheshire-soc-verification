// ============================================================================
// tb_top.sv — Top-level UVM Testbench for Cheshire SoC
//
// Architecture Decision:
//   We instantiate cheshire_soc DIRECTLY (not through fixture_cheshire_soc)
//   to avoid signal conflicts with the Cheshire VIP. This gives us full
//   control over all protocol signals via UVM agents.
//
//   For DRAM, we reuse Cheshire's VIP DRAM model since building a custom
//   AXI memory model is out-of-scope for protocol verification.
//
// Connections:
//   - JTAG:  UVM jtag_agent drives TCK/TMS/TDI, observes TDO
//   - UART:  UVM uart_agent drives RX, monitors TX
//   - SPI:   UVM spi_agent acts as slave, responds on sd_i
//   - I2C:   UVM i2c_agent acts as slave, open-drain wired-AND
//   - GPIO:  UVM gpio_agent drives gpio_i, monitors gpio_o/gpio_en_o
// ============================================================================

`include "uvm_macros.svh"
`include "cheshire/typedef.svh"

module tb_top;

    import uvm_pkg::*;
    import cheshire_pkg::*;
    import tb_cheshire_pkg::*;

    // Import our UVM packages
    import jtag_pkg::*;
    import uart_pkg::*;
    import spi_pkg::*;
    import i2c_pkg::*;
    import gpio_pkg::*;
    import chs_axi_pkg::*;
    import chs_env_pkg::*;
    import chs_seq_pkg::*;
    import chs_test_pkg::*;

    // ═══════════════════════════════════════════
    // Cheshire Configuration
    // ═══════════════════════════════════════════
    localparam int unsigned SelectedCfg = 32'd0;
    localparam cheshire_cfg_t DutCfg = TbCheshireConfigs[SelectedCfg];

    // Generate Cheshire's parameterized types
    `CHESHIRE_TYPEDEF_ALL(, DutCfg)

    // Derived localparams for SPI CS count (package-level, not in cheshire_cfg_t)
    localparam int unsigned SpihNumCs  = cheshire_pkg::SpihNumCs;

    // ═══════════════════════════════════════════
    // Clock, Reset, Boot Mode
    // ═══════════════════════════════════════════
    logic       clk;
    logic       rst_n;
    logic       test_mode;
    logic [1:0] boot_mode;
    logic       rtc;

    // System clock generation (e.g. 50 MHz)
    localparam int unsigned ClkPeriodNs = 20;
    initial begin
        clk = 1'b0;
        forever #(ClkPeriodNs / 2) clk = ~clk;
    end

    // RTC generation (e.g. 32.768 kHz)
    localparam int unsigned RtcPeriodNs = 30518;  // ~32.768 kHz
    initial begin
        rtc = 1'b0;
        forever #(RtcPeriodNs / 2) rtc = ~rtc;
    end

    // Reset sequence
    initial begin
        rst_n     = 1'b0;
        test_mode = 1'b0;
        boot_mode = 2'b00;   // Default: idle boot, overridden by test
        #(ClkPeriodNs * 20);
        rst_n = 1'b1;
    end

    // ═══════════════════════════════════════════
    // Protocol Signal Declarations
    // ═══════════════════════════════════════════

    // JTAG
    logic jtag_tck;
    logic jtag_trst_n;
    logic jtag_tms;
    logic jtag_tdi;
    logic jtag_tdo;

    // UART
    logic uart_tx;
    logic uart_rx;

    // I2C (split signals from DUT)
    logic i2c_sda_o, i2c_sda_i, i2c_sda_en;
    logic i2c_scl_o, i2c_scl_i, i2c_scl_en;

    // SPI Host (split signals from DUT)
    logic                 spih_sck_o,  spih_sck_en;
    logic [SpihNumCs-1:0] spih_csb_o,  spih_csb_en;
    logic [3:0]           spih_sd_o,   spih_sd_i,  spih_sd_en;

    // GPIO
    logic [31:0] gpio_i, gpio_o, gpio_en_o;

    // Serial Link (directly tied off — not verified by UVM)
    localparam int unsigned SlinkNumChan  = cheshire_pkg::SlinkNumChan;
    localparam int unsigned SlinkNumLanes = cheshire_pkg::SlinkNumLanes;
    logic [SlinkNumChan-1:0]                    slink_rcv_clk_i;
    logic [SlinkNumChan-1:0]                    slink_rcv_clk_o;
    logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_i;
    logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_o;

    // AXI LLC Master (for DRAM model)
    axi_llc_req_t axi_llc_mst_req;
    axi_llc_rsp_t axi_llc_mst_rsp;

    // ═══════════════════════════════════════════
    // DUT: cheshire_soc (direct instantiation)
    // ═══════════════════════════════════════════
    cheshire_soc #(
        .Cfg                ( DutCfg ),
        .ExtHartinfo        ( '0 ),
        .axi_ext_llc_req_t  ( axi_llc_req_t ),
        .axi_ext_llc_rsp_t  ( axi_llc_rsp_t ),
        .axi_ext_mst_req_t  ( axi_mst_req_t ),
        .axi_ext_mst_rsp_t  ( axi_mst_rsp_t ),
        .axi_ext_slv_req_t  ( axi_slv_req_t ),
        .axi_ext_slv_rsp_t  ( axi_slv_rsp_t ),
        .reg_ext_req_t      ( reg_req_t ),
        .reg_ext_rsp_t      ( reg_rsp_t )
    ) dut (
        .clk_i              ( clk       ),
        .rst_ni             ( rst_n     ),
        .test_mode_i        ( test_mode ),
        .boot_mode_i        ( boot_mode ),
        .rtc_i              ( rtc       ),
        // AXI LLC → DRAM model
        .axi_llc_mst_req_o  ( axi_llc_mst_req ),
        .axi_llc_mst_rsp_i  ( axi_llc_mst_rsp ),
        // External AXI masters/slaves (unused)
        .axi_ext_mst_req_i  ( '0 ),
        .axi_ext_mst_rsp_o  (    ),
        .axi_ext_slv_req_o  (    ),
        .axi_ext_slv_rsp_i  ( '0 ),
        // External register interface (unused)
        .reg_ext_slv_req_o  (    ),
        .reg_ext_slv_rsp_i  ( '0 ),
        // Interrupts
        .intr_ext_i         ( '0 ),
        .intr_ext_o         (    ),
        .xeip_ext_o         (    ),
        .mtip_ext_o         (    ),
        .msip_ext_o         (    ),
        // Debug
        .dbg_active_o       (    ),
        .dbg_ext_req_o      (    ),
        .dbg_ext_unavail_i  ( '0 ),
        // JTAG — driven by UVM jtag_agent
        .jtag_tck_i         ( jtag_tck    ),
        .jtag_trst_ni       ( jtag_trst_n ),
        .jtag_tms_i         ( jtag_tms    ),
        .jtag_tdi_i         ( jtag_tdi    ),
        .jtag_tdo_o         ( jtag_tdo    ),
        .jtag_tdo_oe_o      (             ),
        // UART — driven/monitored by UVM uart_agent
        .uart_tx_o          ( uart_tx  ),
        .uart_rx_i          ( uart_rx  ),
        .uart_rts_no        (          ),
        .uart_dtr_no        (          ),
        .uart_cts_ni        ( 1'b0     ),
        .uart_dsr_ni        ( 1'b0     ),
        .uart_dcd_ni        ( 1'b0     ),
        .uart_rin_ni        ( 1'b0     ),
        // I2C — driven/monitored by UVM i2c_agent
        .i2c_sda_o          ( i2c_sda_o   ),
        .i2c_sda_i          ( i2c_sda_i   ),
        .i2c_sda_en_o       ( i2c_sda_en  ),
        .i2c_scl_o          ( i2c_scl_o   ),
        .i2c_scl_i          ( i2c_scl_i   ),
        .i2c_scl_en_o       ( i2c_scl_en  ),
        // SPI Host — driven/monitored by UVM spi_agent
        .spih_sck_o         ( spih_sck_o   ),
        .spih_sck_en_o      ( spih_sck_en  ),
        .spih_csb_o         ( spih_csb_o   ),
        .spih_csb_en_o      ( spih_csb_en  ),
        .spih_sd_o          ( spih_sd_o    ),
        .spih_sd_en_o       ( spih_sd_en   ),
        .spih_sd_i          ( spih_sd_i    ),
        // GPIO — driven/monitored by UVM gpio_agent
        .gpio_i             ( gpio_i      ),
        .gpio_o             ( gpio_o      ),
        .gpio_en_o          ( gpio_en_o   ),
        // Serial Link (directly tied, not UVM-verified)
        .slink_rcv_clk_i    ( slink_rcv_clk_i ),
        .slink_rcv_clk_o    ( slink_rcv_clk_o ),
        .slink_i            ( slink_i ),
        .slink_o            ( slink_o ),
        // VGA (unused)
        .vga_hsync_o        (     ),
        .vga_vsync_o        (     ),
        .vga_red_o          (     ),
        .vga_green_o        (     ),
        .vga_blue_o         (     ),
        // USB (unused)
        .usb_clk_i          ( 1'b0 ),
        .usb_rst_ni         ( 1'b1 ),
        .usb_dm_i           ( '0   ),
        .usb_dm_o           (      ),
        .usb_dm_oe_o        (      ),
        .usb_dp_i           ( '0   ),
        .usb_dp_o           (      ),
        .usb_dp_oe_o        (      )
    );

    // ═══════════════════════════════════════════
    // DRAM Model (simple AXI slave memory)
    // Uses Cheshire's sim_mem from axi_sim_mem
    // ═══════════════════════════════════════════
    axi_sim_mem #(
        .AddrWidth   ( DutCfg.AddrWidth        ),
        .DataWidth   ( DutCfg.AxiDataWidth     ),
        .IdWidth     ( $bits(axi_llc_id_t)     ),
        .UserWidth   ( DutCfg.AxiUserWidth     ),
        .NumPorts    ( 32'd1                   ),
        .axi_req_t   ( axi_llc_req_t           ),
        .axi_rsp_t   ( axi_llc_rsp_t           )
    ) i_dram_model (
        .clk_i              ( clk              ),
        .rst_ni             ( rst_n            ),
        .axi_req_i          ( axi_llc_mst_req  ),
        .axi_rsp_o          ( axi_llc_mst_rsp  ),
        .mon_w_valid_o      (                  ),
        .mon_w_addr_o       (                  ),
        .mon_w_data_o       (                  ),
        .mon_w_id_o         (                  ),
        .mon_w_user_o       (                  ),
        .mon_w_beat_count_o (                  ),
        .mon_w_last_o       (                  ),
        .mon_r_valid_o      (                  ),
        .mon_r_addr_o       (                  ),
        .mon_r_data_o       (                  ),
        .mon_r_id_o         (                  ),
        .mon_r_user_o       (                  ),
        .mon_r_beat_count_o (                  ),
        .mon_r_last_o       (                  )
    );

    // Serial Link tie-off
    assign slink_rcv_clk_i = '0;
    assign slink_i         = '0;

    // ═══════════════════════════════════════════
    // UVM Interface Instantiation
    // ═══════════════════════════════════════════

    // JTAG interface
    jtag_if jtag_vif (
        .clk   ( clk   ),
        .rst_n ( rst_n )
    );

    // UART interface
    uart_if uart_vif (
        .clk   ( clk   ),
        .rst_n ( rst_n )
    );

    // SPI interface
    spi_if spi_vif (
        .clk   ( clk   ),
        .rst_n ( rst_n )
    );

    // I2C interface
    i2c_if i2c_vif (
        .clk   ( clk   ),
        .rst_n ( rst_n )
    );

    // GPIO interface
    gpio_if gpio_vif (
        .clk   ( clk   ),
        .rst_n ( rst_n )
    );

    // ═══════════════════════════════════════════
    // AXI LLC Interface (for monitoring DRAM port)
    // ═══════════════════════════════════════════
    // Note: Uses default chs_axi_if parameters (48,64,6,2) which must
    // match the actual Cheshire LLC port widths. The $bits() check at
    // elaboration time acts as a compile-time assertion.
    chs_axi_if axi_llc_vif (
        .aclk    ( clk   ),
        .aresetn ( rst_n )
    );

    // ═══════════════════════════════════════════
    // Signal Wiring: UVM Interfaces ↔ DUT
    // ═══════════════════════════════════════════

    // --- JTAG (UVM agent drives, DUT receives) ---
    assign jtag_tck    = jtag_vif.tck;
    assign jtag_trst_n = jtag_vif.trst_n;
    assign jtag_tms    = jtag_vif.tms;
    assign jtag_tdi    = jtag_vif.tdi;
    assign jtag_vif.tdo = jtag_tdo;       // DUT TDO → UVM monitor

    // --- UART ---
    assign uart_vif.tx = uart_tx;          // DUT TX → UVM monitor captures
    assign uart_rx     = uart_vif.rx;      // UVM driver → DUT RX

    // --- SPI (DUT is master, UVM agent is slave) ---
    assign spi_vif.sck   = spih_sck_o;
    assign spi_vif.csb   = spih_csb_o[SpihNumCs-1:0];
    assign spi_vif.sd_o  = spih_sd_o;
    assign spi_vif.sd_en = spih_sd_en;
    assign spih_sd_i     = spi_vif.sd_i;   // UVM slave response → DUT MISO

    // --- I2C (open-drain bus model in i2c_if handles resolution) ---
    assign i2c_vif.scl_o  = i2c_scl_o;
    assign i2c_vif.scl_en = i2c_scl_en;
    assign i2c_vif.sda_o  = i2c_sda_o;
    assign i2c_vif.sda_en = i2c_sda_en;
    // i2c_if internally resolves the bus and feeds back to _i
    assign i2c_scl_i = i2c_vif.scl_bus;   // Resolved SCL → DUT
    assign i2c_sda_i = i2c_vif.sda_bus;   // Resolved SDA → DUT

    // --- GPIO (UVM agent drives inputs, monitors outputs) ---
    assign gpio_i             = gpio_vif.gpio_i;     // UVM driver → DUT inputs
    assign gpio_vif.gpio_o    = gpio_o;               // DUT outputs → UVM monitor
    assign gpio_vif.gpio_en_o = gpio_en_o;            // DUT enables → UVM monitor

    // --- AXI LLC (passive monitoring — extract struct fields to interface) ---
    // Write Address Channel
    assign axi_llc_vif.awid    = axi_llc_mst_req.aw.id;
    assign axi_llc_vif.awaddr  = axi_llc_mst_req.aw.addr;
    assign axi_llc_vif.awlen   = axi_llc_mst_req.aw.len;
    assign axi_llc_vif.awsize  = axi_llc_mst_req.aw.size;
    assign axi_llc_vif.awburst = axi_llc_mst_req.aw.burst;
    assign axi_llc_vif.awlock  = axi_llc_mst_req.aw.lock;
    assign axi_llc_vif.awcache = axi_llc_mst_req.aw.cache;
    assign axi_llc_vif.awprot  = axi_llc_mst_req.aw.prot;
    assign axi_llc_vif.awqos   = axi_llc_mst_req.aw.qos;
    assign axi_llc_vif.awuser  = axi_llc_mst_req.aw.user;
    assign axi_llc_vif.awvalid = axi_llc_mst_req.aw_valid;
    assign axi_llc_vif.awready = axi_llc_mst_rsp.aw_ready;
    assign axi_llc_vif.awatop  = axi_llc_mst_req.aw.atop;
    // Write Data Channel
    assign axi_llc_vif.wdata   = axi_llc_mst_req.w.data;
    assign axi_llc_vif.wstrb   = axi_llc_mst_req.w.strb;
    assign axi_llc_vif.wlast   = axi_llc_mst_req.w.last;
    assign axi_llc_vif.wuser   = axi_llc_mst_req.w.user;
    assign axi_llc_vif.wvalid  = axi_llc_mst_req.w_valid;
    assign axi_llc_vif.wready  = axi_llc_mst_rsp.w_ready;
    // Write Response Channel
    assign axi_llc_vif.bid     = axi_llc_mst_rsp.b.id;
    assign axi_llc_vif.bresp   = axi_llc_mst_rsp.b.resp;
    assign axi_llc_vif.buser   = axi_llc_mst_rsp.b.user;
    assign axi_llc_vif.bvalid  = axi_llc_mst_rsp.b_valid;
    assign axi_llc_vif.bready  = axi_llc_mst_req.b_ready;
    // Read Address Channel
    assign axi_llc_vif.arid    = axi_llc_mst_req.ar.id;
    assign axi_llc_vif.araddr  = axi_llc_mst_req.ar.addr;
    assign axi_llc_vif.arlen   = axi_llc_mst_req.ar.len;
    assign axi_llc_vif.arsize  = axi_llc_mst_req.ar.size;
    assign axi_llc_vif.arburst = axi_llc_mst_req.ar.burst;
    assign axi_llc_vif.arlock  = axi_llc_mst_req.ar.lock;
    assign axi_llc_vif.arcache = axi_llc_mst_req.ar.cache;
    assign axi_llc_vif.arprot  = axi_llc_mst_req.ar.prot;
    assign axi_llc_vif.arqos   = axi_llc_mst_req.ar.qos;
    assign axi_llc_vif.aruser  = axi_llc_mst_req.ar.user;
    assign axi_llc_vif.arvalid = axi_llc_mst_req.ar_valid;
    assign axi_llc_vif.arready = axi_llc_mst_rsp.ar_ready;
    // Read Data Channel
    assign axi_llc_vif.rid     = axi_llc_mst_rsp.r.id;
    assign axi_llc_vif.rdata   = axi_llc_mst_rsp.r.data;
    assign axi_llc_vif.rresp   = axi_llc_mst_rsp.r.resp;
    assign axi_llc_vif.rlast   = axi_llc_mst_rsp.r.last;
    assign axi_llc_vif.ruser   = axi_llc_mst_rsp.r.user;
    assign axi_llc_vif.rvalid  = axi_llc_mst_rsp.r_valid;
    assign axi_llc_vif.rready  = axi_llc_mst_req.r_ready;

    // ═══════════════════════════════════════════
    // UVM Config DB — Pass interfaces to agents
    // ═══════════════════════════════════════════
    initial begin
        uvm_config_db#(virtual jtag_if)::set(null,
            "uvm_test_top.m_env.m_jtag_agent*", "vif", jtag_vif);
        uvm_config_db#(virtual uart_if)::set(null,
            "uvm_test_top.m_env.m_uart_agent*", "vif", uart_vif);
        uvm_config_db#(virtual spi_if)::set(null,
            "uvm_test_top.m_env.m_spi_agent*", "vif", spi_vif);
        uvm_config_db#(virtual i2c_if)::set(null,
            "uvm_test_top.m_env.m_i2c_agent*", "vif", i2c_vif);
        uvm_config_db#(virtual gpio_if)::set(null,
            "uvm_test_top.m_env.m_gpio_agent*", "vif", gpio_vif);
        uvm_config_db#(virtual chs_axi_if)::set(null,
            "uvm_test_top.m_env.m_axi_agent*", "vif", axi_llc_vif);
    end

    // ═══════════════════════════════════════════
    // SVA Protocol Checker (Asama 5)
    // ═══════════════════════════════════════════
    chs_protocol_checker #(
        .SYS_CLK_PERIOD_NS  ( ClkPeriodNs ),
        .JTAG_TCK_PERIOD_NS ( 20          ),
        .NUM_SPI_CS          ( SpihNumCs   )
    ) i_protocol_checker (
        // System
        .clk             ( clk              ),
        .rst_n           ( rst_n            ),
        // JTAG
        .jtag_tck        ( jtag_tck         ),
        .jtag_trst_n     ( jtag_trst_n      ),
        .jtag_tms        ( jtag_tms         ),
        .jtag_tdi        ( jtag_tdi         ),
        .jtag_tdo        ( jtag_tdo         ),
        // UART
        .uart_tx         ( uart_tx          ),
        .uart_rx         ( uart_rx          ),
        // SPI Host
        .spih_sck        ( spih_sck_o       ),
        .spih_csb        ( spih_csb_o       ),
        .spih_sd_o       ( spih_sd_o        ),
        .spih_sd_en      ( spih_sd_en       ),
        .spih_sd_i       ( spih_sd_i        ),
        // I2C
        .i2c_scl_o       ( i2c_scl_o        ),
        .i2c_scl_en      ( i2c_scl_en       ),
        .i2c_sda_o       ( i2c_sda_o        ),
        .i2c_sda_en      ( i2c_sda_en       ),
        .i2c_scl_bus     ( i2c_vif.scl_bus  ),
        .i2c_sda_bus     ( i2c_vif.sda_bus  ),
        // GPIO
        .gpio_i          ( gpio_i           ),
        .gpio_o          ( gpio_o           ),
        .gpio_en_o       ( gpio_en_o        )
    );

    // ═══════════════════════════════════════════
    // SoC-Level SVA Checker (Aşama 7)
    // Uses hierarchical references to DUT internals
    // ═══════════════════════════════════════════
    chs_soc_sva_checker i_soc_sva_checker (
        .clk        ( clk       ),
        .rst_n      ( rst_n     ),
        .boot_mode  ( boot_mode )
    );

    // ═══════════════════════════════════════════
    // AXI Protocol Checker (Aşama 8)
    // Monitors AXI LLC/DRAM port for ARM IHI 0022F compliance
    // 50+ assertions, 18+ cover properties
    // ═══════════════════════════════════════════
    chs_axi_protocol_checker #(
        .AXI_ADDR_WIDTH  ( 48               ),
        .AXI_DATA_WIDTH  ( 64               ),
        .AXI_ID_WIDTH    ( 6                ),
        .AXI_USER_WIDTH  ( 2                ),
        .PORT_NAME       ( "AXI_LLC_DRAM"   )
    ) i_axi_protocol_checker (
        .aclk    ( clk   ),
        .aresetn ( rst_n ),
        // AW
        .awid    ( axi_llc_vif.awid    ),
        .awaddr  ( axi_llc_vif.awaddr  ),
        .awlen   ( axi_llc_vif.awlen   ),
        .awsize  ( axi_llc_vif.awsize  ),
        .awburst ( axi_llc_vif.awburst ),
        .awlock  ( axi_llc_vif.awlock  ),
        .awcache ( axi_llc_vif.awcache ),
        .awprot  ( axi_llc_vif.awprot  ),
        .awqos   ( axi_llc_vif.awqos   ),
        .awuser  ( axi_llc_vif.awuser  ),
        .awvalid ( axi_llc_vif.awvalid ),
        .awready ( axi_llc_vif.awready ),
        .awatop  ( axi_llc_vif.awatop  ),
        // W
        .wdata   ( axi_llc_vif.wdata   ),
        .wstrb   ( axi_llc_vif.wstrb   ),
        .wlast   ( axi_llc_vif.wlast   ),
        .wuser   ( axi_llc_vif.wuser   ),
        .wvalid  ( axi_llc_vif.wvalid  ),
        .wready  ( axi_llc_vif.wready  ),
        // B
        .bid     ( axi_llc_vif.bid     ),
        .bresp   ( axi_llc_vif.bresp   ),
        .buser   ( axi_llc_vif.buser   ),
        .bvalid  ( axi_llc_vif.bvalid  ),
        .bready  ( axi_llc_vif.bready  ),
        // AR
        .arid    ( axi_llc_vif.arid    ),
        .araddr  ( axi_llc_vif.araddr  ),
        .arlen   ( axi_llc_vif.arlen   ),
        .arsize  ( axi_llc_vif.arsize  ),
        .arburst ( axi_llc_vif.arburst ),
        .arlock  ( axi_llc_vif.arlock  ),
        .arcache ( axi_llc_vif.arcache ),
        .arprot  ( axi_llc_vif.arprot  ),
        .arqos   ( axi_llc_vif.arqos   ),
        .aruser  ( axi_llc_vif.aruser  ),
        .arvalid ( axi_llc_vif.arvalid ),
        .arready ( axi_llc_vif.arready ),
        // R
        .rid     ( axi_llc_vif.rid     ),
        .rdata   ( axi_llc_vif.rdata   ),
        .rresp   ( axi_llc_vif.rresp   ),
        .rlast   ( axi_llc_vif.rlast   ),
        .ruser   ( axi_llc_vif.ruser   ),
        .rvalid  ( axi_llc_vif.rvalid  ),
        .rready  ( axi_llc_vif.rready  )
    );

    // ═══════════════════════════════════════════
    // Boot Mode Override via plusarg
    // ═══════════════════════════════════════════
    initial begin
        int bm;
        if ($value$plusargs("BOOT_MODE=%0d", bm))
            boot_mode = bm[1:0];
    end

    // ═══════════════════════════════════════════
    // UVM Entry Point
    // ═══════════════════════════════════════════
    initial begin
        run_test();
    end

    // ═══════════════════════════════════════════
    // Waveform Dump
    // ═══════════════════════════════════════════
    initial begin
        if ($test$plusargs("DUMP_VCD")) begin
            $dumpfile("cheshire_uvm.vcd");
            $dumpvars(0, tb_top);
        end
    end

endmodule : tb_top
