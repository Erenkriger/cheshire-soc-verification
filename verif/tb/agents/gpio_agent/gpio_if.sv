// ============================================================================
// gpio_if.sv — GPIO Interface (OpenTitan GPIO, 32-bit)
// Cheshire GPIO ports: gpio_i[31:0] (input to DUT),
//   gpio_o[31:0] (output from DUT), gpio_en_o[31:0] (output enable)
// ============================================================================

interface gpio_if (
    input logic clk,
    input logic rst_n
);

    logic [31:0] gpio_i;       // TB → DUT input stimulus
    logic [31:0] gpio_o;       // DUT → TB output data
    logic [31:0] gpio_en_o;    // DUT → TB output enable

    // Driver clocking block (TB drives gpio_i into DUT)
    clocking drv_cb @(posedge clk);
        default input #1 output #1;
        output gpio_i;
        input  gpio_o;
        input  gpio_en_o;
    endclocking

    // Monitor clocking block (observes all signals)
    clocking mon_cb @(posedge clk);
        default input #1;
        input gpio_i;
        input gpio_o;
        input gpio_en_o;
    endclocking

    modport DUT_SIDE (input gpio_i, output gpio_o, output gpio_en_o);
    modport TB_SIDE  (output gpio_i, input gpio_o, input gpio_en_o,
                      clocking drv_cb);
    modport MONITOR  (input gpio_i, input gpio_o, input gpio_en_o,
                      clocking mon_cb);

endinterface : gpio_if
