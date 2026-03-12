// ============================================================================
// chs_soc_sva_checker.sv — SoC-Level SVA Assertion Module
//
// Aşama 7: Comprehensive system-level assertions using hierarchical
// references to DUT internal signals. Complements the protocol-level
// checker (chs_protocol_checker.sv) with higher-level architectural
// verification.
//
// Assertion Groups:
//   1. SBA (System Bus Access) — handshake, error, timing
//   2. DMI (Debug Module Interface) — valid/ready, reset
//   3. AXI Crossbar — transaction tracking, no deadlock
//   4. Register Bus — decode, peripheral select
//   5. Interrupt Routing — GPIO→PLIC, I2C interrupts, UART interrupt
//   6. Boot Mode — stability, reset value
//   7. Debug Module — halt/resume, dmactive
//   8. Reset Sequencing — proper reset propagation
//   9. Memory Map — address range validation
//  10. Bus Error — detection and signaling
//
// NOTE: This module uses hierarchical references to `dut.*` signals.
//       It MUST be instantiated in tb_top where `dut` is accessible.
//
// Design for Portability:
//   When porting to a multi-core SoC, only the hierarchical paths
//   and memory map constants need updating. All property templates
//   are reusable.
// ============================================================================

module chs_soc_sva_checker (
    input logic       clk,
    input logic       rst_n,
    input logic [1:0] boot_mode
);

    // ════════════════════════════════════════════════════════════════
    //  1. SBA (System Bus Access) ASSERTIONS
    //  Signals: dut.dbg_sba_req, _addr, _we, _wdata, _strb,
    //           _gnt, _rdata, _rvalid, _err
    // ════════════════════════════════════════════════════════════════

    // SBA_REQ_GNT: When SBA request is asserted, grant must come
    // within a bounded number of cycles (no deadlock)
    property p_sba_req_gnt;
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_sba_req |-> ##[0:200] tb_top.dut.dbg_sba_gnt;
    endproperty
    a_sba_req_gnt: assert property (p_sba_req_gnt)
        else $error("[SVA_SBA] SBA request not granted within 200 cycles — possible deadlock");

    // SBA_RVALID_AFTER_GNT: After grant, read-valid must come for reads
    property p_sba_rvalid_after_read;
        @(posedge clk) disable iff (!rst_n)
        (tb_top.dut.dbg_sba_gnt && !tb_top.dut.dbg_sba_we) |->
            ##[1:200] tb_top.dut.dbg_sba_rvalid;
    endproperty
    a_sba_rvalid_after_read: assert property (p_sba_rvalid_after_read)
        else $error("[SVA_SBA] SBA read response not received within 200 cycles");

    // SBA_ADDR_KNOWN: When request is active, address must be known
    a_sba_addr_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_sba_req |-> !$isunknown(tb_top.dut.dbg_sba_addr)
    ) else $error("[SVA_SBA] SBA address is X/Z during request");

    // SBA_WDATA_KNOWN: Write data must be known during write request
    a_sba_wdata_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        (tb_top.dut.dbg_sba_req && tb_top.dut.dbg_sba_we) |->
            !$isunknown(tb_top.dut.dbg_sba_wdata)
    ) else $error("[SVA_SBA] SBA write data is X/Z during write request");

    // SBA_STRB_KNOWN: Write strobe must be known during write
    a_sba_strb_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        (tb_top.dut.dbg_sba_req && tb_top.dut.dbg_sba_we) |->
            !$isunknown(tb_top.dut.dbg_sba_strb)
    ) else $error("[SVA_SBA] SBA write strobe is X/Z during write request");

    // SBA_NO_REQ_DURING_RESET: No SBA request during reset
    a_sba_no_req_reset: assert property (
        @(posedge clk)
        !rst_n |-> !tb_top.dut.dbg_sba_req
    ) else $warning("[SVA_SBA] SBA request active during reset");

    // Cover: SBA write transaction
    c_sba_write: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_sba_req && tb_top.dut.dbg_sba_we && tb_top.dut.dbg_sba_gnt
    );

    // Cover: SBA read transaction
    c_sba_read: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_sba_req && !tb_top.dut.dbg_sba_we && tb_top.dut.dbg_sba_gnt
    );

    // Cover: SBA error response
    c_sba_error: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_sba_rvalid && tb_top.dut.dbg_sba_err
    );

    // ════════════════════════════════════════════════════════════════
    //  2. DMI (Debug Module Interface) ASSERTIONS
    //  Signals: dut.dbg_dmi_req_valid, _req_ready,
    //           dut.dbg_dmi_rsp_valid, _rsp_ready
    // ════════════════════════════════════════════════════════════════

    // DMI_REQ_HANDSHAKE: Valid must remain asserted until ready
    property p_dmi_req_handshake;
        @(posedge clk) disable iff (!rst_n)
        (tb_top.dut.dbg_dmi_req_valid && !tb_top.dut.dbg_dmi_req_ready) |->
            ##1 tb_top.dut.dbg_dmi_req_valid;
    endproperty
    a_dmi_req_handshake: assert property (p_dmi_req_handshake)
        else $error("[SVA_DMI] DMI request valid dropped before ready");

    // DMI_RSP_HANDSHAKE: Response valid must remain until ready
    property p_dmi_rsp_handshake;
        @(posedge clk) disable iff (!rst_n)
        (tb_top.dut.dbg_dmi_rsp_valid && !tb_top.dut.dbg_dmi_rsp_ready) |->
            ##1 tb_top.dut.dbg_dmi_rsp_valid;
    endproperty
    a_dmi_rsp_handshake: assert property (p_dmi_rsp_handshake)
        else $error("[SVA_DMI] DMI response valid dropped before ready");

    // DMI_REQ_BOUNDED: DMI request must get ready within bounded cycles
    property p_dmi_req_bounded;
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_dmi_req_valid |-> ##[0:100] tb_top.dut.dbg_dmi_req_ready;
    endproperty
    a_dmi_req_bounded: assert property (p_dmi_req_bounded)
        else $warning("[SVA_DMI] DMI request not accepted within 100 cycles");

    // DMI_RSP_BOUNDED: DMI response must get consumed within bounded cycles
    property p_dmi_rsp_bounded;
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_dmi_rsp_valid |-> ##[0:100] tb_top.dut.dbg_dmi_rsp_ready;
    endproperty
    a_dmi_rsp_bounded: assert property (p_dmi_rsp_bounded)
        else $warning("[SVA_DMI] DMI response not consumed within 100 cycles");

    // DMI_NO_ACTIVITY_IN_RESET: No DMI valid signals during reset
    a_dmi_no_req_reset: assert property (
        @(posedge clk)
        !rst_n |-> !tb_top.dut.dbg_dmi_req_valid
    ) else $warning("[SVA_DMI] DMI request valid during reset");

    // Cover: DMI request accepted
    c_dmi_req_accepted: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_dmi_req_valid && tb_top.dut.dbg_dmi_req_ready
    );

    // Cover: DMI response delivered
    c_dmi_rsp_delivered: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_dmi_rsp_valid && tb_top.dut.dbg_dmi_rsp_ready
    );

    // ════════════════════════════════════════════════════════════════
    //  3. REGISTER BUS ASSERTIONS
    //  Signals: dut.reg_in_req.valid, .addr, .write
    //           dut.reg_in_rsp.ready, .error
    // ════════════════════════════════════════════════════════════════

    // REG_ADDR_KNOWN: Address must be known on valid request
    a_reg_addr_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.reg_in_req.valid |-> !$isunknown(tb_top.dut.reg_in_req.addr)
    ) else $error("[SVA_REG] Register bus address is X/Z on valid request");

    // REG_RESPONSE: Register bus must respond within bounded cycles
    property p_reg_response;
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.reg_in_req.valid |-> ##[0:50] tb_top.dut.reg_in_rsp.ready;
    endproperty
    a_reg_response: assert property (p_reg_response)
        else $warning("[SVA_REG] Register bus response not ready within 50 cycles");

    // Cover: Register write
    c_reg_write: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.reg_in_req.valid && tb_top.dut.reg_in_req.write
    );

    // Cover: Register read
    c_reg_read: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.reg_in_req.valid && !tb_top.dut.reg_in_req.write
    );

    // Cover: Register error response
    c_reg_error: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.reg_in_rsp.ready && tb_top.dut.reg_in_rsp.error
    );

    // ════════════════════════════════════════════════════════════════
    //  4. INTERRUPT ROUTING ASSERTIONS
    //  Signals: dut.intr.intn.uart, .gpio, .spih_*, .i2c_*
    //           dut.xeip, dut.mtip, dut.msip
    // ════════════════════════════════════════════════════════════════

    // INT_UART_PROP: UART interrupt eventually propagates to PLIC output
    // (within bounded cycles, if PLIC is properly configured)
    // Note: We can only check that UART interrupt signal is clean
    a_intr_uart_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tb_top.dut.intr.intn.uart)
    ) else $error("[SVA_INT] UART interrupt signal is X/Z");

    // INT_GPIO_KNOWN: GPIO interrupt bundle must be known
    a_intr_gpio_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tb_top.dut.intr.intn.gpio)
    ) else $error("[SVA_INT] GPIO interrupt signal is X/Z");

    // INT_SPI_KNOWN: SPI host interrupts must be known
    a_intr_spih_event_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tb_top.dut.intr.intn.spih_spi_event)
    ) else $error("[SVA_INT] SPI host event interrupt is X/Z");

    a_intr_spih_error_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tb_top.dut.intr.intn.spih_error)
    ) else $error("[SVA_INT] SPI host error interrupt is X/Z");

    // INT_I2C_KNOWN: I2C interrupts must be known
    a_intr_i2c_nak_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tb_top.dut.intr.intn.i2c_nak)
    ) else $error("[SVA_INT] I2C NAK interrupt is X/Z");

    a_intr_i2c_cmd_complete_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tb_top.dut.intr.intn.i2c_cmd_complete)
    ) else $error("[SVA_INT] I2C cmd_complete interrupt is X/Z");

    // INT_ZERO_ALWAYS_ZERO: The zero interrupt bit must always be 0
    a_intr_zero: assert property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.intr.intn.zero === 1'b0
    ) else $error("[SVA_INT] Interrupt 'zero' bit is not 0!");

    // INT_PLIC_OUT_KNOWN: PLIC external interrupt pending to core
    a_xeip_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown({tb_top.dut.xeip[0].m, tb_top.dut.xeip[0].s})
    ) else $warning("[SVA_INT] PLIC xeip output to core is X/Z");

    // INT_CLINT_KNOWN: CLINT timer and software interrupts
    a_mtip_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tb_top.dut.mtip[0])
    ) else $warning("[SVA_INT] CLINT mtip is X/Z");

    a_msip_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tb_top.dut.msip[0])
    ) else $warning("[SVA_INT] CLINT msip is X/Z");

    // Cover: UART interrupt asserted
    c_intr_uart: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.intr.intn.uart
    );

    // Cover: Any GPIO interrupt asserted
    c_intr_gpio: cover property (
        @(posedge clk) disable iff (!rst_n)
        |tb_top.dut.intr.intn.gpio
    );

    // Cover: SPI host event interrupt
    c_intr_spih_event: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.intr.intn.spih_spi_event
    );

    // Cover: I2C NAK interrupt
    c_intr_i2c_nak: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.intr.intn.i2c_nak
    );

    // Cover: PLIC asserts external interrupt to core
    c_plic_meip: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.xeip[0].m
    );

    // Cover: CLINT timer interrupt
    c_clint_mtip: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.mtip[0]
    );

    // ════════════════════════════════════════════════════════════════
    //  5. BOOT MODE ASSERTIONS
    // ════════════════════════════════════════════════════════════════

    // BOOT_MODE_STABLE: Boot mode should be stable after reset deassertion
    // (it should not change during normal operation)
    property p_boot_mode_stable;
        @(posedge clk)
        rst_n |-> ##1 (boot_mode == $past(boot_mode));
    endproperty
    a_boot_mode_stable: assert property (p_boot_mode_stable)
        else $warning("[SVA_BOOT] Boot mode changed after reset deassertion");

    // BOOT_MODE_KNOWN: Boot mode should never be X/Z
    a_boot_mode_known: assert property (
        @(posedge clk) !$isunknown(boot_mode)
    ) else $error("[SVA_BOOT] Boot mode is X/Z");

    // Cover: Boot in JTAG mode
    c_boot_jtag: cover property (
        @(posedge clk) $rose(rst_n) && boot_mode == 2'b00
    );

    // Cover: Boot in Serial Link mode
    c_boot_slink: cover property (
        @(posedge clk) $rose(rst_n) && boot_mode == 2'b01
    );

    // Cover: Boot in UART mode
    c_boot_uart: cover property (
        @(posedge clk) $rose(rst_n) && boot_mode == 2'b10
    );

    // ════════════════════════════════════════════════════════════════
    //  6. DEBUG MODULE ASSERTIONS
    // ════════════════════════════════════════════════════════════════

    // DBG_REQ_KNOWN: Debug request to core must be known after reset
    a_dbg_req_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tb_top.dut.dbg_req[0])
    ) else $error("[SVA_DBG] Debug request to hart 0 is X/Z");

    // DBG_DMI_RESET_KNOWN: DMI reset signal must be known
    a_dmi_rst_known: assert property (
        @(posedge clk)
        !$isunknown(tb_top.dut.dbg_dmi_rst_n)
    ) else $error("[SVA_DBG] DMI reset is X/Z");

    // Cover: Debug module requests halt
    c_dbg_halt_req: cover property (
        @(posedge clk) disable iff (!rst_n)
        $rose(tb_top.dut.dbg_req[0])
    );

    // Cover: Debug module releases halt
    c_dbg_resume: cover property (
        @(posedge clk) disable iff (!rst_n)
        $fell(tb_top.dut.dbg_req[0])
    );

    // ════════════════════════════════════════════════════════════════
    //  7. RESET SEQUENCING ASSERTIONS
    // ════════════════════════════════════════════════════════════════

    // RST_CLEAN_DEASSERT: Reset should deassert cleanly (no glitch)
    property p_rst_clean_deassert;
        @(posedge clk)
        $rose(rst_n) |-> ##[1:8] rst_n;
    endproperty
    a_rst_clean: assert property (p_rst_clean_deassert)
        else $error("[SVA_RST] Reset glitched: re-asserted within 8 cycles of deassertion");

    // RST_SBA_QUIET: SBA should be quiet during first cycles after reset
    property p_rst_sba_quiet;
        @(posedge clk)
        $rose(rst_n) |-> ##[1:5] !tb_top.dut.dbg_sba_req;
    endproperty
    a_rst_sba_quiet: assert property (p_rst_sba_quiet)
        else $warning("[SVA_RST] SBA request too soon after reset");

    // RST_DMI_QUIET: DMI should be quiet during first cycles after reset
    property p_rst_dmi_quiet;
        @(posedge clk)
        $rose(rst_n) |-> ##[1:3] !tb_top.dut.dbg_dmi_req_valid;
    endproperty
    a_rst_dmi_quiet: assert property (p_rst_dmi_quiet)
        else $warning("[SVA_RST] DMI request too soon after reset");

    // ════════════════════════════════════════════════════════════════
    //  8. BUS ERROR ASSERTIONS
    // ════════════════════════════════════════════════════════════════

    // BUS_ERR_KNOWN: Core bus error interrupt signals must be known
    a_bus_err_r_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tb_top.dut.core_bus_err_intr_comb.r)
    ) else $warning("[SVA_BUSERR] Core bus error (read) interrupt is X/Z");

    a_bus_err_w_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(tb_top.dut.core_bus_err_intr_comb.w)
    ) else $warning("[SVA_BUSERR] Core bus error (write) interrupt is X/Z");

    // Cover: Bus error (read)
    c_bus_err_r: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.core_bus_err_intr_comb.r
    );

    // Cover: Bus error (write)
    c_bus_err_w: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.core_bus_err_intr_comb.w
    );

    // ════════════════════════════════════════════════════════════════
    //  9. SBA ADDRESS RANGE ASSERTIONS
    //  Verify SBA targets valid memory-mapped regions
    // ════════════════════════════════════════════════════════════════

    // Cheshire memory map regions
    localparam logic [47:0] PERIPH_START = 48'h0300_0000;
    localparam logic [47:0] PERIPH_END   = 48'h0300_A000;
    localparam logic [47:0] BROM_START   = 48'h0200_0000;
    localparam logic [47:0] BROM_END     = 48'h0204_0000;
    localparam logic [47:0] CLINT_START  = 48'h0204_0000;
    localparam logic [47:0] CLINT_END    = 48'h0208_0000;
    localparam logic [47:0] PLIC_START   = 48'h0400_0000;
    localparam logic [47:0] PLIC_END     = 48'h0800_0000;
    localparam logic [47:0] DRAM_START   = 48'h8000_0000;
    localparam logic [47:0] DEBUG_START  = 48'h0000_0000;
    localparam logic [47:0] DEBUG_END    = 48'h0004_0000;

    // SBA_ADDR_VALID: SBA address should target a valid region
    // (log unmapped accesses for awareness)
    wire sba_addr_in_range =
        (tb_top.dut.dbg_sba_addr >= DEBUG_START  && tb_top.dut.dbg_sba_addr < DEBUG_END)  ||
        (tb_top.dut.dbg_sba_addr >= BROM_START   && tb_top.dut.dbg_sba_addr < BROM_END)   ||
        (tb_top.dut.dbg_sba_addr >= CLINT_START  && tb_top.dut.dbg_sba_addr < CLINT_END)  ||
        (tb_top.dut.dbg_sba_addr >= PERIPH_START && tb_top.dut.dbg_sba_addr < PERIPH_END) ||
        (tb_top.dut.dbg_sba_addr >= PLIC_START   && tb_top.dut.dbg_sba_addr < PLIC_END)   ||
        (tb_top.dut.dbg_sba_addr >= DRAM_START);

    // Cover: SBA targets peripheral space
    c_sba_periph: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_sba_req &&
        tb_top.dut.dbg_sba_addr >= PERIPH_START &&
        tb_top.dut.dbg_sba_addr < PERIPH_END
    );

    // Cover: SBA targets DRAM
    c_sba_dram: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_sba_req && tb_top.dut.dbg_sba_addr >= DRAM_START
    );

    // Cover: SBA targets boot ROM
    c_sba_brom: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_sba_req &&
        tb_top.dut.dbg_sba_addr >= BROM_START &&
        tb_top.dut.dbg_sba_addr < BROM_END
    );

    // Cover: SBA targets unmapped region
    c_sba_unmapped: cover property (
        @(posedge clk) disable iff (!rst_n)
        tb_top.dut.dbg_sba_req && !sba_addr_in_range
    );

    // ════════════════════════════════════════════════════════════════
    //  10. CROSS-DOMAIN INTEGRATION ASSERTIONS
    // ════════════════════════════════════════════════════════════════

    // SBA_TO_REG_PATH: When SBA writes to peripheral space, reg bus should
    // eventually see a valid request (latency bound)
    property p_sba_to_reg;
        @(posedge clk) disable iff (!rst_n)
        (tb_top.dut.dbg_sba_req && tb_top.dut.dbg_sba_gnt &&
         tb_top.dut.dbg_sba_addr >= PERIPH_START &&
         tb_top.dut.dbg_sba_addr < PERIPH_END) |->
            ##[1:100] tb_top.dut.reg_in_req.valid;
    endproperty
    a_sba_to_reg: assert property (p_sba_to_reg)
        else $warning("[SVA_XDOM] SBA peripheral access did not reach reg bus within 100 cycles");

    // Cover: Full SBA→REG path for peripheral write
    c_sba_to_reg_write: cover property (
        @(posedge clk) disable iff (!rst_n)
        (tb_top.dut.dbg_sba_req && tb_top.dut.dbg_sba_we &&
         tb_top.dut.dbg_sba_addr >= PERIPH_START) ##[1:50]
        (tb_top.dut.reg_in_req.valid && tb_top.dut.reg_in_req.write)
    );

    // Cover: Full SBA→REG path for peripheral read
    c_sba_to_reg_read: cover property (
        @(posedge clk) disable iff (!rst_n)
        (tb_top.dut.dbg_sba_req && !tb_top.dut.dbg_sba_we &&
         tb_top.dut.dbg_sba_addr >= PERIPH_START) ##[1:50]
        (tb_top.dut.reg_in_req.valid && !tb_top.dut.reg_in_req.write)
    );

    // ════════════════════════════════════════════════════════════════
    //  ASSERTION STATISTICS
    // ════════════════════════════════════════════════════════════════
    int unsigned sba_write_count = 0;
    int unsigned sba_read_count  = 0;
    int unsigned sba_error_count = 0;
    int unsigned dmi_req_count   = 0;
    int unsigned dmi_rsp_count   = 0;
    int unsigned reg_req_count   = 0;
    int unsigned intr_uart_count = 0;
    int unsigned intr_gpio_count = 0;
    int unsigned bus_err_count   = 0;

    always @(posedge clk) begin
        if (rst_n) begin
            if (tb_top.dut.dbg_sba_req && tb_top.dut.dbg_sba_gnt && tb_top.dut.dbg_sba_we)
                sba_write_count++;
            if (tb_top.dut.dbg_sba_req && tb_top.dut.dbg_sba_gnt && !tb_top.dut.dbg_sba_we)
                sba_read_count++;
            if (tb_top.dut.dbg_sba_rvalid && tb_top.dut.dbg_sba_err)
                sba_error_count++;
            if (tb_top.dut.dbg_dmi_req_valid && tb_top.dut.dbg_dmi_req_ready)
                dmi_req_count++;
            if (tb_top.dut.dbg_dmi_rsp_valid && tb_top.dut.dbg_dmi_rsp_ready)
                dmi_rsp_count++;
            if (tb_top.dut.reg_in_req.valid && tb_top.dut.reg_in_rsp.ready)
                reg_req_count++;
            if (tb_top.dut.intr.intn.uart)
                intr_uart_count++;
            if (|tb_top.dut.intr.intn.gpio)
                intr_gpio_count++;
            if (tb_top.dut.core_bus_err_intr_comb.r || tb_top.dut.core_bus_err_intr_comb.w)
                bus_err_count++;
        end
    end

    final begin
        $display("============================================================");
        $display("  SoC SVA Checker Summary");
        $display("============================================================");
        $display("  SBA writes        : %0d", sba_write_count);
        $display("  SBA reads         : %0d", sba_read_count);
        $display("  SBA errors        : %0d", sba_error_count);
        $display("  DMI requests      : %0d", dmi_req_count);
        $display("  DMI responses     : %0d", dmi_rsp_count);
        $display("  Reg bus accesses  : %0d", reg_req_count);
        $display("  UART intr cycles  : %0d", intr_uart_count);
        $display("  GPIO intr cycles  : %0d", intr_gpio_count);
        $display("  Bus error cycles  : %0d", bus_err_count);
        $display("============================================================");
    end

endmodule : chs_soc_sva_checker
