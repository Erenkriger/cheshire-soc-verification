// ============================================================================
// slink_if.sv — Serial Link Interface
// Cheshire Serial Link: multi-channel, multi-lane DDR serial interface
// for chip-to-chip communication.
//
// Default: 1 channel, 4 lanes (from serial_link_single_channel_reg_pkg)
// ============================================================================

interface slink_if #(
    parameter int unsigned NUM_CHAN  = 1,
    parameter int unsigned NUM_LANES = 4
)(
    input logic clk,
    input logic rst_n
);

    // TX side (DUT → external)
    logic [NUM_CHAN-1:0]                    rcv_clk_o;   // DUT output receive clock
    logic [NUM_CHAN-1:0][NUM_LANES-1:0]     data_o;      // DUT output data lanes

    // RX side (external → DUT)
    logic [NUM_CHAN-1:0]                    rcv_clk_i;   // TB drives receive clock
    logic [NUM_CHAN-1:0][NUM_LANES-1:0]     data_i;      // TB drives data lanes

    // Driver clocking block (TB drives RX side into DUT)
    clocking drv_cb @(posedge clk);
        default input #1 output #1;
        output rcv_clk_i;
        output data_i;
        input  rcv_clk_o;
        input  data_o;
    endclocking

    // Monitor clocking block (observes all signals)
    clocking mon_cb @(posedge clk);
        default input #1;
        input rcv_clk_o;
        input data_o;
        input rcv_clk_i;
        input data_i;
    endclocking

    modport DUT_SIDE (input rcv_clk_i, input data_i, output rcv_clk_o, output data_o);
    modport TB_SIDE  (output rcv_clk_i, output data_i, input rcv_clk_o, input data_o,
                      clocking drv_cb);
    modport MONITOR  (input rcv_clk_i, input data_i, input rcv_clk_o, input data_o,
                      clocking mon_cb);

endinterface : slink_if
