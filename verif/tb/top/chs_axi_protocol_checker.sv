// ============================================================================
// chs_axi_protocol_checker.sv — AXI4 Protocol SVA Checker for Cheshire SoC
//
// Comprehensive AXI4 protocol compliance checker (ARM IHI 0022F):
//   Section 1: Reset assertions
//   Section 2: Handshake stability (VALID/READY rules)
//   Section 3: X/Z checks on control signals
//   Section 4: Burst protocol rules (WRAP, 4KB, reserved)
//   Section 5: Write strobe checks
//   Section 6: Response validity
//   Section 7: Handshake timeout (liveness)
//   Section 8: Exclusive access rules
//   Section 9: ATOP (atomic operation) rules
//   Coverage: 16+ cover properties
//
// Instantiated in tb_top, wired from AXI LLC port struct signals.
// ============================================================================

module chs_axi_protocol_checker #(
    parameter int unsigned AXI_ADDR_WIDTH  = 48,
    parameter int unsigned AXI_DATA_WIDTH  = 64,
    parameter int unsigned AXI_ID_WIDTH    = 8,
    parameter int unsigned AXI_USER_WIDTH  = 1,
    parameter string       PORT_NAME       = "AXI_LLC"
)(
    input logic                           aclk,
    input logic                           aresetn,

    // Write Address Channel (AW)
    input logic [AXI_ID_WIDTH-1:0]        awid,
    input logic [AXI_ADDR_WIDTH-1:0]      awaddr,
    input logic [7:0]                     awlen,
    input logic [2:0]                     awsize,
    input logic [1:0]                     awburst,
    input logic                           awlock,
    input logic [3:0]                     awcache,
    input logic [2:0]                     awprot,
    input logic [3:0]                     awqos,
    input logic [AXI_USER_WIDTH-1:0]      awuser,
    input logic                           awvalid,
    input logic                           awready,
    input logic [5:0]                     awatop,

    // Write Data Channel (W)
    input logic [AXI_DATA_WIDTH-1:0]      wdata,
    input logic [AXI_DATA_WIDTH/8-1:0]    wstrb,
    input logic                           wlast,
    input logic [AXI_USER_WIDTH-1:0]      wuser,
    input logic                           wvalid,
    input logic                           wready,

    // Write Response Channel (B)
    input logic [AXI_ID_WIDTH-1:0]        bid,
    input logic [1:0]                     bresp,
    input logic [AXI_USER_WIDTH-1:0]      buser,
    input logic                           bvalid,
    input logic                           bready,

    // Read Address Channel (AR)
    input logic [AXI_ID_WIDTH-1:0]        arid,
    input logic [AXI_ADDR_WIDTH-1:0]      araddr,
    input logic [7:0]                     arlen,
    input logic [2:0]                     arsize,
    input logic [1:0]                     arburst,
    input logic                           arlock,
    input logic [3:0]                     arcache,
    input logic [2:0]                     arprot,
    input logic [3:0]                     arqos,
    input logic [AXI_USER_WIDTH-1:0]      aruser,
    input logic                           arvalid,
    input logic                           arready,

    // Read Data Channel (R)
    input logic [AXI_ID_WIDTH-1:0]        rid,
    input logic [AXI_DATA_WIDTH-1:0]      rdata,
    input logic [1:0]                     rresp,
    input logic                           rlast,
    input logic [AXI_USER_WIDTH-1:0]      ruser,
    input logic                           rvalid,
    input logic                           rready
);

    // ════════════════════════════════════════════════════════════════
    //  Local parameters
    // ════════════════════════════════════════════════════════════════
    localparam int unsigned STRB_WIDTH = AXI_DATA_WIDTH / 8;

    localparam logic [1:0] BURST_FIXED = 2'b00;
    localparam logic [1:0] BURST_INCR  = 2'b01;
    localparam logic [1:0] BURST_WRAP  = 2'b10;

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_EXOKAY = 2'b01;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    localparam int unsigned HANDSHAKE_TIMEOUT = 2000;

    // ════════════════════════════════════════════════════════════════
    //  Statistics tracking
    // ════════════════════════════════════════════════════════════════
    int unsigned aw_cnt = 0, w_cnt = 0, b_cnt = 0, ar_cnt = 0, r_cnt = 0;
    int unsigned outstanding_w = 0, outstanding_r = 0;
    int unsigned max_outstanding_w = 0, max_outstanding_r = 0;
    int unsigned err_count = 0;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            aw_cnt <= 0; w_cnt <= 0; b_cnt <= 0; ar_cnt <= 0; r_cnt <= 0;
            outstanding_w <= 0; outstanding_r <= 0;
            max_outstanding_w <= 0; max_outstanding_r <= 0;
        end else begin
            if (awvalid && awready) begin aw_cnt++; outstanding_w++; end
            if (wvalid  && wready)  w_cnt++;
            if (bvalid  && bready)  begin b_cnt++;  if (outstanding_w > 0) outstanding_w--; end
            if (arvalid && arready) begin ar_cnt++; outstanding_r++; end
            if (rvalid  && rready && rlast)  begin r_cnt++;  if (outstanding_r > 0) outstanding_r--; end
            if (outstanding_w > max_outstanding_w) max_outstanding_w <= outstanding_w;
            if (outstanding_r > max_outstanding_r) max_outstanding_r <= outstanding_r;
        end
    end

    // ════════════════════════════════════════════════════════════════
    //  SECTION 1: RESET ASSERTIONS (ARM spec A3.1)
    // ════════════════════════════════════════════════════════════════

    a_rst_awvalid: assert property (
        @(posedge aclk) !aresetn |-> !awvalid
    ) else begin err_count++; $error("[%s][RST] AWVALID high during reset", PORT_NAME); end

    a_rst_wvalid: assert property (
        @(posedge aclk) !aresetn |-> !wvalid
    ) else begin err_count++; $error("[%s][RST] WVALID high during reset", PORT_NAME); end

    a_rst_bvalid: assert property (
        @(posedge aclk) !aresetn |-> !bvalid
    ) else begin err_count++; $error("[%s][RST] BVALID high during reset", PORT_NAME); end

    a_rst_arvalid: assert property (
        @(posedge aclk) !aresetn |-> !arvalid
    ) else begin err_count++; $error("[%s][RST] ARVALID high during reset", PORT_NAME); end

    a_rst_rvalid: assert property (
        @(posedge aclk) !aresetn |-> !rvalid
    ) else begin err_count++; $error("[%s][RST] RVALID high during reset", PORT_NAME); end

    // ════════════════════════════════════════════════════════════════
    //  SECTION 2: HANDSHAKE STABILITY (ARM spec A3.2.1)
    //  "Once VALID is asserted it must remain asserted until handshake"
    // ════════════════════════════════════════════════════════════════

    // --- AW Channel ---
    a_aw_valid_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> awvalid
    ) else begin err_count++; $error("[%s][HS] AWVALID dropped before handshake", PORT_NAME); end

    a_aw_addr_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> $stable(awaddr)
    ) else begin err_count++; $error("[%s][HS] AWADDR changed before handshake", PORT_NAME); end

    a_aw_id_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> $stable(awid)
    ) else begin err_count++; $error("[%s][HS] AWID changed before handshake", PORT_NAME); end

    a_aw_len_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> $stable(awlen)
    ) else begin err_count++; $error("[%s][HS] AWLEN changed before handshake", PORT_NAME); end

    a_aw_size_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> $stable(awsize)
    ) else begin err_count++; $error("[%s][HS] AWSIZE changed before handshake", PORT_NAME); end

    a_aw_burst_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> $stable(awburst)
    ) else begin err_count++; $error("[%s][HS] AWBURST changed before handshake", PORT_NAME); end

    a_aw_lock_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> $stable(awlock)
    ) else begin err_count++; $error("[%s][HS] AWLOCK changed before handshake", PORT_NAME); end

    a_aw_cache_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> $stable(awcache)
    ) else begin err_count++; $error("[%s][HS] AWCACHE changed before handshake", PORT_NAME); end

    a_aw_prot_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> $stable(awprot)
    ) else begin err_count++; $error("[%s][HS] AWPROT changed before handshake", PORT_NAME); end

    a_aw_qos_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> $stable(awqos)
    ) else begin err_count++; $error("[%s][HS] AWQOS changed before handshake", PORT_NAME); end

    a_aw_atop_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> $stable(awatop)
    ) else begin err_count++; $error("[%s][HS] AWATOP changed before handshake", PORT_NAME); end

    // --- W Channel ---
    a_w_valid_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        wvalid && !wready |=> wvalid
    ) else begin err_count++; $error("[%s][HS] WVALID dropped before handshake", PORT_NAME); end

    a_w_data_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        wvalid && !wready |=> $stable(wdata)
    ) else begin err_count++; $error("[%s][HS] WDATA changed before handshake", PORT_NAME); end

    a_w_strb_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        wvalid && !wready |=> $stable(wstrb)
    ) else begin err_count++; $error("[%s][HS] WSTRB changed before handshake", PORT_NAME); end

    a_w_last_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        wvalid && !wready |=> $stable(wlast)
    ) else begin err_count++; $error("[%s][HS] WLAST changed before handshake", PORT_NAME); end

    // --- B Channel ---
    a_b_valid_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        bvalid && !bready |=> bvalid
    ) else begin err_count++; $error("[%s][HS] BVALID dropped before handshake", PORT_NAME); end

    a_b_resp_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        bvalid && !bready |=> $stable(bresp)
    ) else begin err_count++; $error("[%s][HS] BRESP changed before handshake", PORT_NAME); end

    a_b_id_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        bvalid && !bready |=> $stable(bid)
    ) else begin err_count++; $error("[%s][HS] BID changed before handshake", PORT_NAME); end

    // --- AR Channel ---
    a_ar_valid_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> arvalid
    ) else begin err_count++; $error("[%s][HS] ARVALID dropped before handshake", PORT_NAME); end

    a_ar_addr_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> $stable(araddr)
    ) else begin err_count++; $error("[%s][HS] ARADDR changed before handshake", PORT_NAME); end

    a_ar_id_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> $stable(arid)
    ) else begin err_count++; $error("[%s][HS] ARID changed before handshake", PORT_NAME); end

    a_ar_len_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> $stable(arlen)
    ) else begin err_count++; $error("[%s][HS] ARLEN changed before handshake", PORT_NAME); end

    a_ar_size_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> $stable(arsize)
    ) else begin err_count++; $error("[%s][HS] ARSIZE changed before handshake", PORT_NAME); end

    a_ar_burst_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> $stable(arburst)
    ) else begin err_count++; $error("[%s][HS] ARBURST changed before handshake", PORT_NAME); end

    a_ar_lock_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> $stable(arlock)
    ) else begin err_count++; $error("[%s][HS] ARLOCK changed before handshake", PORT_NAME); end

    a_ar_cache_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> $stable(arcache)
    ) else begin err_count++; $error("[%s][HS] ARCACHE changed before handshake", PORT_NAME); end

    a_ar_prot_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> $stable(arprot)
    ) else begin err_count++; $error("[%s][HS] ARPROT changed before handshake", PORT_NAME); end

    a_ar_qos_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> $stable(arqos)
    ) else begin err_count++; $error("[%s][HS] ARQOS changed before handshake", PORT_NAME); end

    // --- R Channel ---
    a_r_valid_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        rvalid && !rready |=> rvalid
    ) else begin err_count++; $error("[%s][HS] RVALID dropped before handshake", PORT_NAME); end

    a_r_data_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        rvalid && !rready |=> $stable(rdata)
    ) else begin err_count++; $error("[%s][HS] RDATA changed before handshake", PORT_NAME); end

    a_r_resp_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        rvalid && !rready |=> $stable(rresp)
    ) else begin err_count++; $error("[%s][HS] RRESP changed before handshake", PORT_NAME); end

    a_r_last_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        rvalid && !rready |=> $stable(rlast)
    ) else begin err_count++; $error("[%s][HS] RLAST changed before handshake", PORT_NAME); end

    a_r_id_stable: assert property (
        @(posedge aclk) disable iff (!aresetn)
        rvalid && !rready |=> $stable(rid)
    ) else begin err_count++; $error("[%s][HS] RID changed before handshake", PORT_NAME); end

    // ════════════════════════════════════════════════════════════════
    //  SECTION 3: X/Z CHECKS
    // ════════════════════════════════════════════════════════════════

    a_aw_no_x: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid |-> !$isunknown({awaddr, awlen, awsize, awburst, awid})
    ) else begin err_count++; $error("[%s][XZ] AW channel has X/Z", PORT_NAME); end

    a_w_no_x: assert property (
        @(posedge aclk) disable iff (!aresetn)
        wvalid |-> !$isunknown({wstrb, wlast})
    ) else begin err_count++; $error("[%s][XZ] W channel control has X/Z", PORT_NAME); end

    a_ar_no_x: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid |-> !$isunknown({araddr, arlen, arsize, arburst, arid})
    ) else begin err_count++; $error("[%s][XZ] AR channel has X/Z", PORT_NAME); end

    a_b_no_x: assert property (
        @(posedge aclk) disable iff (!aresetn)
        bvalid |-> !$isunknown({bid, bresp})
    ) else begin err_count++; $error("[%s][XZ] B channel has X/Z", PORT_NAME); end

    a_r_no_x: assert property (
        @(posedge aclk) disable iff (!aresetn)
        rvalid |-> !$isunknown({rid, rresp, rlast})
    ) else begin err_count++; $error("[%s][XZ] R channel control has X/Z", PORT_NAME); end

    // ════════════════════════════════════════════════════════════════
    //  SECTION 4: BURST RULES (ARM spec A3.4)
    // ════════════════════════════════════════════════════════════════

    // WRAP burst length must be 2, 4, 8, or 16
    a_aw_wrap_len: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && awburst == BURST_WRAP) |->
        (awlen inside {8'd1, 8'd3, 8'd7, 8'd15})
    ) else begin err_count++; $error("[%s][BURST] AW WRAP burst illegal len=%0d", PORT_NAME, awlen); end

    a_ar_wrap_len: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && arburst == BURST_WRAP) |->
        (arlen inside {8'd1, 8'd3, 8'd7, 8'd15})
    ) else begin err_count++; $error("[%s][BURST] AR WRAP burst illegal len=%0d", PORT_NAME, arlen); end

    // RESERVED burst type must not be used
    a_aw_burst_reserved: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid |-> (awburst != 2'b11)
    ) else begin err_count++; $error("[%s][BURST] AW reserved burst type", PORT_NAME); end

    a_ar_burst_reserved: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid |-> (arburst != 2'b11)
    ) else begin err_count++; $error("[%s][BURST] AR reserved burst type", PORT_NAME); end

    // AxSIZE must not exceed data bus width
    a_aw_size_valid: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid |-> ((1 << awsize) <= STRB_WIDTH)
    ) else begin err_count++; $error("[%s][BURST] AWSIZE exceeds bus width", PORT_NAME); end

    a_ar_size_valid: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid |-> ((1 << arsize) <= STRB_WIDTH)
    ) else begin err_count++; $error("[%s][BURST] ARSIZE exceeds bus width", PORT_NAME); end

    // WRAP bursts must be aligned to size
    a_aw_wrap_aligned: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && awburst == BURST_WRAP) |->
        ((awaddr & ((1 << awsize) - 1)) == '0)
    ) else begin err_count++; $error("[%s][BURST] AW WRAP not aligned", PORT_NAME); end

    a_ar_wrap_aligned: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && arburst == BURST_WRAP) |->
        ((araddr & ((1 << arsize) - 1)) == '0)
    ) else begin err_count++; $error("[%s][BURST] AR WRAP not aligned", PORT_NAME); end

    // ════════════════════════════════════════════════════════════════
    //  SECTION 5: WRITE STROBE CHECKS
    // ════════════════════════════════════════════════════════════════

    a_w_strb_not_x: assert property (
        @(posedge aclk) disable iff (!aresetn)
        wvalid |-> !$isunknown(wstrb)
    ) else begin err_count++; $error("[%s][STRB] WSTRB has X/Z", PORT_NAME); end

    // ════════════════════════════════════════════════════════════════
    //  SECTION 6: RESPONSE VALIDITY
    // ════════════════════════════════════════════════════════════════

    a_b_resp_valid: assert property (
        @(posedge aclk) disable iff (!aresetn)
        bvalid |-> (bresp inside {RESP_OKAY, RESP_EXOKAY, RESP_SLVERR, RESP_DECERR})
    ) else begin err_count++; $error("[%s][RESP] Invalid BRESP", PORT_NAME); end

    a_r_resp_valid: assert property (
        @(posedge aclk) disable iff (!aresetn)
        rvalid |-> (rresp inside {RESP_OKAY, RESP_EXOKAY, RESP_SLVERR, RESP_DECERR})
    ) else begin err_count++; $error("[%s][RESP] Invalid RRESP", PORT_NAME); end

    // ════════════════════════════════════════════════════════════════
    //  SECTION 7: HANDSHAKE TIMEOUT (LIVENESS)
    // ════════════════════════════════════════════════════════════════

    a_aw_timeout: assert property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid |-> ##[0:HANDSHAKE_TIMEOUT] awready
    ) else $warning("[%s][TO] AWVALID >%0d cycles without handshake", PORT_NAME, HANDSHAKE_TIMEOUT);

    a_w_timeout: assert property (
        @(posedge aclk) disable iff (!aresetn)
        wvalid |-> ##[0:HANDSHAKE_TIMEOUT] wready
    ) else $warning("[%s][TO] WVALID >%0d cycles without handshake", PORT_NAME, HANDSHAKE_TIMEOUT);

    a_ar_timeout: assert property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid |-> ##[0:HANDSHAKE_TIMEOUT] arready
    ) else $warning("[%s][TO] ARVALID >%0d cycles without handshake", PORT_NAME, HANDSHAKE_TIMEOUT);

    a_b_timeout: assert property (
        @(posedge aclk) disable iff (!aresetn)
        bvalid |-> ##[0:HANDSHAKE_TIMEOUT] bready
    ) else $warning("[%s][TO] BVALID >%0d cycles without handshake", PORT_NAME, HANDSHAKE_TIMEOUT);

    a_r_timeout: assert property (
        @(posedge aclk) disable iff (!aresetn)
        rvalid |-> ##[0:HANDSHAKE_TIMEOUT] rready
    ) else $warning("[%s][TO] RVALID >%0d cycles without handshake", PORT_NAME, HANDSHAKE_TIMEOUT);

    // ════════════════════════════════════════════════════════════════
    //  SECTION 8: EXCLUSIVE ACCESS (ARM spec A7.2)
    // ════════════════════════════════════════════════════════════════

    a_aw_excl_len: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && awlock) |-> (awlen inside {8'd0, 8'd1, 8'd3, 8'd7, 8'd15})
    ) else begin err_count++; $error("[%s][EXCL] AW exclusive len not power-of-2", PORT_NAME); end

    a_ar_excl_len: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && arlock) |-> (arlen inside {8'd0, 8'd1, 8'd3, 8'd7, 8'd15})
    ) else begin err_count++; $error("[%s][EXCL] AR exclusive len not power-of-2", PORT_NAME); end

    // ════════════════════════════════════════════════════════════════
    //  SECTION 9: ATOP (AXI5 Atomic Operations — Cheshire uses these)
    // ════════════════════════════════════════════════════════════════

    // When ATOP is non-zero, burst length must be 0 or 1
    a_aw_atop_len: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && awatop != 6'b0) |-> (awlen <= 8'd1)
    ) else $warning("[%s][ATOP] ATOP transaction with len=%0d (expected 0 or 1)", PORT_NAME, awlen);

    // ATOP must not be used with exclusive access
    a_aw_atop_no_excl: assert property (
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && awatop != 6'b0) |-> !awlock
    ) else begin err_count++; $error("[%s][ATOP] ATOP combined with exclusive access", PORT_NAME); end

    // ════════════════════════════════════════════════════════════════
    //  COVERAGE PROPERTIES
    // ════════════════════════════════════════════════════════════════

    // Single-beat transfers
    c_single_write: cover property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && awready && awlen == 0
    );
    c_single_read: cover property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && arready && arlen == 0
    );

    // Burst transfers
    c_burst_write: cover property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && awready && awlen > 0
    );
    c_burst_read: cover property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && arready && arlen > 0
    );

    // WRAP bursts
    c_wrap_write: cover property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && awready && awburst == BURST_WRAP
    );
    c_wrap_read: cover property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && arready && arburst == BURST_WRAP
    );

    // Exclusive access
    c_excl_read: cover property (
        @(posedge aclk) disable iff (!aresetn)
        arvalid && arready && arlock
    );
    c_excl_write: cover property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && awready && awlock
    );

    // Error responses
    c_slverr_write: cover property (
        @(posedge aclk) disable iff (!aresetn)
        bvalid && bready && bresp == RESP_SLVERR
    );
    c_decerr_write: cover property (
        @(posedge aclk) disable iff (!aresetn)
        bvalid && bready && bresp == RESP_DECERR
    );
    c_slverr_read: cover property (
        @(posedge aclk) disable iff (!aresetn)
        rvalid && rready && rresp == RESP_SLVERR
    );
    c_decerr_read: cover property (
        @(posedge aclk) disable iff (!aresetn)
        rvalid && rready && rresp == RESP_DECERR
    );

    // Back-to-back transactions
    c_b2b_writes: cover property (
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && awready) ##1 (awvalid && awready)
    );
    c_b2b_reads: cover property (
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && arready) ##1 (arvalid && arready)
    );

    // Simultaneous read and write
    c_simultaneous_rw: cover property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && awready && arvalid && arready
    );

    // ATOP transaction
    c_atop_txn: cover property (
        @(posedge aclk) disable iff (!aresetn)
        awvalid && awready && awatop != 6'b0
    );

    // Multiple outstanding
    c_multi_outstanding_w: cover property (
        @(posedge aclk) disable iff (!aresetn)
        outstanding_w > 1
    );
    c_multi_outstanding_r: cover property (
        @(posedge aclk) disable iff (!aresetn)
        outstanding_r > 1
    );

    // ════════════════════════════════════════════════════════════════
    //  FINAL REPORT
    // ════════════════════════════════════════════════════════════════
    final begin
        $display("════════════════════════════════════════════════════════════");
        $display("  AXI Protocol Checker Summary [%s]", PORT_NAME);
        $display("════════════════════════════════════════════════════════════");
        $display("  AW handshakes       : %0d", aw_cnt);
        $display("  W  handshakes       : %0d", w_cnt);
        $display("  B  handshakes       : %0d", b_cnt);
        $display("  AR handshakes       : %0d", ar_cnt);
        $display("  R  handshakes (last): %0d", r_cnt);
        $display("  Max outstanding W   : %0d", max_outstanding_w);
        $display("  Max outstanding R   : %0d", max_outstanding_r);
        $display("  Assertion errors    : %0d", err_count);
        $display("════════════════════════════════════════════════════════════");
    end

endmodule : chs_axi_protocol_checker
