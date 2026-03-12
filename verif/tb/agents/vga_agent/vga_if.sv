// ============================================================================
// vga_if.sv — VGA Interface (Passive Monitor)
// Cheshire VGA: hsync, vsync, RGB565 (Red=5, Green=6, Blue=5)
// ============================================================================

interface vga_if #(
    parameter int unsigned RED_WIDTH   = 5,
    parameter int unsigned GREEN_WIDTH = 6,
    parameter int unsigned BLUE_WIDTH  = 5
)(
    input logic clk,
    input logic rst_n
);

    logic                      hsync;
    logic                      vsync;
    logic [RED_WIDTH-1:0]      red;
    logic [GREEN_WIDTH-1:0]    green;
    logic [BLUE_WIDTH-1:0]     blue;

    // Monitor clocking block (all inputs, passive observation)
    clocking mon_cb @(posedge clk);
        default input #1;
        input hsync;
        input vsync;
        input red;
        input green;
        input blue;
    endclocking

    modport MONITOR (input hsync, input vsync, input red, input green, input blue,
                     clocking mon_cb);

endinterface : vga_if
