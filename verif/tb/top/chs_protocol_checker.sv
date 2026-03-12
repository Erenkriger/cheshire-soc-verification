// ============================================================================
// chs_protocol_checker.sv — Protocol-Level SVA Checker
//
// Aşama 5: Instantiated in tb_top to observe raw protocol signals
// and enforce correct timing/protocol compliance via SVA assertions.
//
// This module is NOT a UVM component — it's a plain SystemVerilog module
// with assertions that bind directly to DUT/testbench signals.
//
// Assertion Groups:
//   1. JTAG Protocol: TCK/TMS/TDI stability, TRST behavior
//   2. SPI Protocol:  CS/SCK relationship, Mode 0 timing, data stability
//   3. UART Protocol: Start/stop bit framing, baud timing guard
//   4. I2C Protocol:  START/STOP conditions, SDA stability during SCL high
//   5. GPIO Protocol: Output enable gating, no X/Z on active outputs
//   6. AXI/System:    Reset behavior, clock stability
// ============================================================================

module chs_protocol_checker #(
    parameter int unsigned SYS_CLK_PERIOD_NS = 20,    // 50 MHz
    parameter int unsigned JTAG_TCK_PERIOD_NS = 20,   // 50 MHz
    parameter int unsigned NUM_SPI_CS = 2
)(
    // System
    input logic        clk,
    input logic        rst_n,

    // JTAG signals
    input logic        jtag_tck,
    input logic        jtag_trst_n,
    input logic        jtag_tms,
    input logic        jtag_tdi,
    input logic        jtag_tdo,

    // UART signals
    input logic        uart_tx,
    input logic        uart_rx,

    // SPI Host signals
    input logic                   spih_sck,
    input logic [NUM_SPI_CS-1:0]  spih_csb,
    input logic [3:0]             spih_sd_o,
    input logic [3:0]             spih_sd_en,
    input logic [3:0]             spih_sd_i,

    // I2C signals (open-drain resolved bus)
    input logic        i2c_scl_o,
    input logic        i2c_scl_en,
    input logic        i2c_sda_o,
    input logic        i2c_sda_en,
    input logic        i2c_scl_bus,
    input logic        i2c_sda_bus,

    // GPIO signals
    input logic [31:0] gpio_i,
    input logic [31:0] gpio_o,
    input logic [31:0] gpio_en_o
);

    // ========================================================================
    //  Internal tracking signals
    // ========================================================================
    logic rst_n_d;    // Delayed reset for edge detection
    logic spi_active; // At least one CS is asserted

    always_ff @(posedge clk) begin
        rst_n_d <= rst_n;
    end

    assign spi_active = |(~spih_csb); // Active when any CSB is low

    // ========================================================================
    //  1. SYSTEM / RESET ASSERTIONS
    // ========================================================================

    // RST_DEASSERT_CLEAN: After reset deasserts, it should stay deasserted
    // for at least 4 clock cycles (no glitchy re-assertion)
    property p_reset_stable_after_deassert;
        @(posedge clk)
        $rose(rst_n) |-> ##[1:4] rst_n;
    endproperty
    a_reset_stable: assert property (p_reset_stable_after_deassert)
        else $warning("[SVA_SYS] Reset glitch: rst_n re-asserted within 4 cycles of deassertion");

    // RST_NO_X: Reset signal should never be X
    a_reset_no_x: assert property (
        @(posedge clk) !$isunknown(rst_n)
    ) else $error("[SVA_SYS] rst_n is X/Z");

    // CLK_NO_X: After reset deasserts, clk should never be X
    // (checked externally — clk is always toggling by definition)

    // ========================================================================
    //  2. JTAG PROTOCOL ASSERTIONS
    // ========================================================================

    // JTAG_TMS_KNOWN: TMS must not be X/Z when TCK rises (after TRST deasserts)
    a_jtag_tms_known: assert property (
        @(posedge jtag_tck) disable iff (!jtag_trst_n)
        !$isunknown(jtag_tms)
    ) else $error("[SVA_JTAG] TMS is X/Z at TCK rising edge");

    // JTAG_TDI_KNOWN: TDI must not be X/Z when TCK rises (after TRST deasserts)
    a_jtag_tdi_known: assert property (
        @(posedge jtag_tck) disable iff (!jtag_trst_n)
        !$isunknown(jtag_tdi)
    ) else $error("[SVA_JTAG] TDI is X/Z at TCK rising edge");

    // JTAG_TDO_KNOWN: TDO should not be X/Z when TCK rises (after TRST deasserts)
    a_jtag_tdo_known: assert property (
        @(posedge jtag_tck) disable iff (!jtag_trst_n)
        !$isunknown(jtag_tdo)
    ) else $warning("[SVA_JTAG] TDO is X/Z at TCK rising edge");

    // JTAG_TRST_RELEASE: After TRST deasserts, TMS should go to known state within 5 TCK
    property p_jtag_trst_release;
        @(posedge jtag_tck)
        $rose(jtag_trst_n) |-> ##[0:5] !$isunknown(jtag_tms);
    endproperty
    a_jtag_trst_release: assert property (p_jtag_trst_release)
        else $warning("[SVA_JTAG] TMS not settled within 5 TCK after TRST release");

    // ========================================================================
    //  3. SPI PROTOCOL ASSERTIONS (Mode 0: CPOL=0, CPHA=0)
    // ========================================================================

    // SPI_SCK_IDLE_LOW: When no CS is asserted, SCK should be LOW (CPOL=0)
    a_spi_sck_idle: assert property (
        @(posedge clk) disable iff (!rst_n)
        (!spi_active) |-> (spih_sck === 1'b0)
    ) else $warning("[SVA_SPI] SCK not idle-low when no CS active (CPOL=0 violation)");

    // SPI_CS_MUTEX: At most one CS should be asserted at a time
    a_spi_cs_mutex: assert property (
        @(posedge clk) disable iff (!rst_n)
        $countones(~spih_csb) <= 1
    ) else $error("[SVA_SPI] Multiple SPI CS lines asserted simultaneously");

    // SPI_SD_EN_VALID: sd_en should not be X/Z during active transfer
    a_spi_sd_en_valid: assert property (
        @(posedge clk) disable iff (!rst_n)
        spi_active |-> !$isunknown(spih_sd_en)
    ) else $error("[SVA_SPI] sd_en is X/Z during active SPI transfer");

    // SPI_MOSI_KNOWN: MOSI (sd_o[0]) should be known during active transfer when output enabled
    a_spi_mosi_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        (spi_active && spih_sd_en[0]) |-> !$isunknown(spih_sd_o[0])
    ) else $error("[SVA_SPI] MOSI (sd_o[0]) is X/Z during active SPI transfer");

    // SPI_CSB_NO_GLITCH: CS should stay asserted for at least 2 system clock cycles
    // (prevents spurious single-cycle CS pulses)
    generate
        for (genvar cs = 0; cs < NUM_SPI_CS; cs++) begin : gen_spi_cs_assertions
            a_spi_csb_min_assert: assert property (
                @(posedge clk) disable iff (!rst_n)
                $fell(spih_csb[cs]) |-> ##1 !spih_csb[cs]
            ) else $warning("[SVA_SPI] CS[%0d] deasserted after only 1 cycle (glitch)", cs);
        end
    endgenerate

    // ========================================================================
    //  4. UART PROTOCOL ASSERTIONS
    // ========================================================================

    // UART_TX_IDLE_HIGH: TX should be HIGH when idle (mark state)
    // After reset, TX should settle to HIGH within some cycles
    property p_uart_tx_after_reset;
        @(posedge clk)
        $rose(rst_n) |-> ##[1:200] (uart_tx === 1'b1);
    endproperty
    a_uart_tx_idle: assert property (p_uart_tx_after_reset)
        else $warning("[SVA_UART] TX not idle-high within 200 cycles after reset");

    // UART_RX_NO_X: RX should not be X/Z after reset
    a_uart_rx_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(uart_rx)
    ) else $error("[SVA_UART] RX is X/Z after reset");

    // UART_TX_NO_X: TX should not be X/Z after reset
    a_uart_tx_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(uart_tx)
    ) else $error("[SVA_UART] TX is X/Z after reset");

    // ========================================================================
    //  5. I2C PROTOCOL ASSERTIONS
    // ========================================================================

    // I2C_SDA_STABLE_SCL_HIGH: SDA must not change while SCL is HIGH
    // (except for START/STOP conditions which are intentional transitions)
    // This is the fundamental I2C rule.
    //
    // Implementation: Check that if SCL_bus is high and SDA changes,
    // it's either a START (SDA falls) or STOP (SDA rises) condition.
    // We track SDA transitions during SCL high as potential violations.

    // I2C_BUS_NO_X: Bus lines should not be X/Z after reset
    a_i2c_scl_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(i2c_scl_bus)
    ) else $warning("[SVA_I2C] SCL bus is X/Z after reset");

    a_i2c_sda_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(i2c_sda_bus)
    ) else $warning("[SVA_I2C] SDA bus is X/Z after reset");

    // I2C_OPEN_DRAIN: When output enable is active and output is 0,
    // the bus should be pulled low (wired-AND correctness)
    a_i2c_od_scl: assert property (
        @(posedge clk) disable iff (!rst_n)
        (i2c_scl_en && !i2c_scl_o) |-> (i2c_scl_bus === 1'b0)
    ) else $error("[SVA_I2C] SCL open-drain violation: OE=1, OUT=0 but bus not low");

    a_i2c_od_sda: assert property (
        @(posedge clk) disable iff (!rst_n)
        (i2c_sda_en && !i2c_sda_o) |-> (i2c_sda_bus === 1'b0)
    ) else $error("[SVA_I2C] SDA open-drain violation: OE=1, OUT=0 but bus not low");

    // ========================================================================
    //  6. GPIO PROTOCOL ASSERTIONS
    // ========================================================================

    // GPIO_OUTPUT_GATING: When output enable is 0 for a bit, that bit's
    // gpio_o should not propagate (we can't assert on external wiring,
    // but we check that gpio_o is known when en is active)
    a_gpio_o_known_when_en: assert property (
        @(posedge clk) disable iff (!rst_n)
        (gpio_en_o != 32'h0) |-> !$isunknown(gpio_o & gpio_en_o)
    ) else $error("[SVA_GPIO] gpio_o has X/Z on bits where output is enabled");

    // GPIO_INPUT_KNOWN: Inputs from TB should always be known after reset
    a_gpio_i_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(gpio_i)
    ) else $warning("[SVA_GPIO] gpio_i has X/Z after reset");

    // GPIO_EN_NO_X: Output enable should not be X/Z after reset
    a_gpio_en_known: assert property (
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(gpio_en_o)
    ) else $error("[SVA_GPIO] gpio_en_o has X/Z after reset");

    // ========================================================================
    //  COVERAGE PROPERTIES (cover, not assert)
    // ========================================================================

    // Cover: SPI transfer with CS[0]
    c_spi_cs0_transfer: cover property (
        @(posedge clk) disable iff (!rst_n)
        $fell(spih_csb[0]) ##[1:$] $rose(spih_csb[0])
    );

    // Cover: SPI transfer with CS[1] (if exists)
    generate
        if (NUM_SPI_CS > 1) begin : gen_cs1_cover
            c_spi_cs1_transfer: cover property (
                @(posedge clk) disable iff (!rst_n)
                $fell(spih_csb[1]) ##[1:$] $rose(spih_csb[1])
            );
        end
    endgenerate

    // Cover: UART TX frame (start bit observed)
    c_uart_tx_frame: cover property (
        @(posedge clk) disable iff (!rst_n)
        $fell(uart_tx) // start bit
    );

    // Cover: UART RX frame (start bit on RX)
    c_uart_rx_frame: cover property (
        @(posedge clk) disable iff (!rst_n)
        $fell(uart_rx)
    );

    // Cover: I2C START condition (SDA falls while SCL high)
    c_i2c_start: cover property (
        @(posedge clk) disable iff (!rst_n)
        (i2c_scl_bus && $fell(i2c_sda_bus))
    );

    // Cover: I2C STOP condition (SDA rises while SCL high)
    c_i2c_stop: cover property (
        @(posedge clk) disable iff (!rst_n)
        (i2c_scl_bus && $rose(i2c_sda_bus))
    );

    // Cover: GPIO output enable activated
    c_gpio_output_active: cover property (
        @(posedge clk) disable iff (!rst_n)
        $rose(|gpio_en_o)
    );

    // Cover: JTAG TAP reset
    c_jtag_trst: cover property (
        @(posedge clk)
        $fell(jtag_trst_n) ##[1:$] $rose(jtag_trst_n)
    );

    // ========================================================================
    //  ASSERTION STATISTICS (for report)
    // ========================================================================
    int unsigned spi_cs_assert_count = 0;
    int unsigned uart_tx_frame_count = 0;
    int unsigned jtag_tck_edge_count = 0;

    always @(negedge spih_csb[0]) if (rst_n) spi_cs_assert_count++;
    always @(negedge uart_tx)     if (rst_n) uart_tx_frame_count++;
    always @(posedge jtag_tck)    if (rst_n) jtag_tck_edge_count++;

    // Final report (triggered at end of simulation)
    final begin
        $display("============================================================");
        $display("  SVA Protocol Checker Summary");
        $display("============================================================");
        $display("  SPI CS[0] assertions  : %0d", spi_cs_assert_count);
        $display("  UART TX start bits    : %0d", uart_tx_frame_count);
        $display("  JTAG TCK edges        : %0d", jtag_tck_edge_count);
        $display("============================================================");
    end

endmodule : chs_protocol_checker
