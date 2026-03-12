// ============================================================================
// i2c_if.sv — I2C Interface (OpenTitan I2C, open-drain model)
// Cheshire I2C ports: i2c_sda_o, i2c_sda_i, i2c_sda_en_o,
//                     i2c_scl_o, i2c_scl_i, i2c_scl_en_o
// Open-drain model: wire = en ? out_val : 1'bz (external pull-up to VDD)
// ============================================================================

interface i2c_if (
    input logic clk,
    input logic rst_n
);

    // DUT-side output enable signals (directly from DUT)
    logic scl_o;       // DUT SCL output value
    logic scl_i;       // SCL input to DUT (from bus)
    logic scl_en;      // DUT SCL output enable

    logic sda_o;       // DUT SDA output value
    logic sda_i;       // SDA input to DUT (from bus)
    logic sda_en;      // DUT SDA output enable

    // Resolved bus values (open-drain with pull-up)
    // In testbench: scl_bus = scl_en ? scl_o : 1'b1 (pulled high)
    //               sda_bus = sda_en ? sda_o : 1'b1 (pulled high)
    // Slave can also pull lines low by driving _i signals
    wire scl_bus;
    wire sda_bus;

    // Model open-drain bus: either side can pull low
    // DUT pulls low when en=1 and o=0; TB slave can also pull low
    logic tb_scl_pull;   // TB slave SCL pull-down (for clock stretching)
    logic tb_sda_pull;   // TB slave SDA pull-down (for ACK/data)

    assign scl_bus = (scl_en && !scl_o) ? 1'b0 :
                     (tb_scl_pull)      ? 1'b0 : 1'b1;
    assign sda_bus = (sda_en && !sda_o) ? 1'b0 :
                     (tb_sda_pull)      ? 1'b0 : 1'b1;

    // Feed resolved bus values back to DUT inputs
    assign scl_i = scl_bus;
    assign sda_i = sda_bus;

    modport DUT_SIDE  (output scl_o, output scl_en, input scl_i,
                       output sda_o, output sda_en, input sda_i);
    modport TB_SIDE   (input scl_bus, input sda_bus,
                       output tb_scl_pull, output tb_sda_pull,
                       input scl_o, input scl_en, input sda_o, input sda_en);
    modport MONITOR   (input scl_bus, input sda_bus,
                       input scl_o, input scl_en, input sda_o, input sda_en);

endinterface : i2c_if
