// ============================================================================
// chs_axi_if.sv — AXI4 Monitoring Interface for Cheshire SoC
//
// Parameterized AXI4 interface with clocking blocks for passive monitoring.
// Used by chs_axi_monitor to observe LLC/DRAM AXI transactions.
//
// Instantiated in tb_top and wired from struct signals.
// ============================================================================

interface chs_axi_if #(
    parameter int unsigned AXI_ADDR_WIDTH = 48,
    parameter int unsigned AXI_DATA_WIDTH = 64,
    parameter int unsigned AXI_ID_WIDTH   = 6,   // Cheshire LLC port: 6-bit ID
    parameter int unsigned AXI_USER_WIDTH = 2    // Cheshire: 2-bit user
)(
    input logic aclk,
    input logic aresetn
);

    localparam int unsigned STRB_WIDTH = AXI_DATA_WIDTH / 8;

    // ════════════════════════════════════════════
    // Write Address Channel (AW)
    // ════════════════════════════════════════════
    logic [AXI_ID_WIDTH-1:0]     awid;
    logic [AXI_ADDR_WIDTH-1:0]   awaddr;
    logic [7:0]                  awlen;
    logic [2:0]                  awsize;
    logic [1:0]                  awburst;
    logic                        awlock;
    logic [3:0]                  awcache;
    logic [2:0]                  awprot;
    logic [3:0]                  awqos;
    logic [3:0]                  awregion;
    logic [AXI_USER_WIDTH-1:0]   awuser;
    logic                        awvalid;
    logic                        awready;
    logic [5:0]                  awatop;

    // ════════════════════════════════════════════
    // Write Data Channel (W)
    // ════════════════════════════════════════════
    logic [AXI_DATA_WIDTH-1:0]   wdata;
    logic [STRB_WIDTH-1:0]       wstrb;
    logic                        wlast;
    logic [AXI_USER_WIDTH-1:0]   wuser;
    logic                        wvalid;
    logic                        wready;

    // ════════════════════════════════════════════
    // Write Response Channel (B)
    // ════════════════════════════════════════════
    logic [AXI_ID_WIDTH-1:0]     bid;
    logic [1:0]                  bresp;
    logic [AXI_USER_WIDTH-1:0]   buser;
    logic                        bvalid;
    logic                        bready;

    // ════════════════════════════════════════════
    // Read Address Channel (AR)
    // ════════════════════════════════════════════
    logic [AXI_ID_WIDTH-1:0]     arid;
    logic [AXI_ADDR_WIDTH-1:0]   araddr;
    logic [7:0]                  arlen;
    logic [2:0]                  arsize;
    logic [1:0]                  arburst;
    logic                        arlock;
    logic [3:0]                  arcache;
    logic [2:0]                  arprot;
    logic [3:0]                  arqos;
    logic [3:0]                  arregion;
    logic [AXI_USER_WIDTH-1:0]   aruser;
    logic                        arvalid;
    logic                        arready;

    // ════════════════════════════════════════════
    // Read Data Channel (R)
    // ════════════════════════════════════════════
    logic [AXI_ID_WIDTH-1:0]     rid;
    logic [AXI_DATA_WIDTH-1:0]   rdata;
    logic [1:0]                  rresp;
    logic                        rlast;
    logic [AXI_USER_WIDTH-1:0]   ruser;
    logic                        rvalid;
    logic                        rready;

    // ════════════════════════════════════════════
    // Monitor Clocking Block
    // ════════════════════════════════════════════
    clocking mon_cb @(posedge aclk);
        default input #1step;
        // AW
        input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
              awqos, awregion, awuser, awvalid, awready, awatop;
        // W
        input wdata, wstrb, wlast, wuser, wvalid, wready;
        // B
        input bid, bresp, buser, bvalid, bready;
        // AR
        input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot,
              arqos, arregion, aruser, arvalid, arready;
        // R
        input rid, rdata, rresp, rlast, ruser, rvalid, rready;
    endclocking

    modport MONITOR (clocking mon_cb, input aclk, input aresetn);

endinterface : chs_axi_if
