// ============================================================================
// usb_if.sv — USB 1.1 Interface (OHCI)
// Cheshire USB: D+/D- differential pair with open-drain control.
// Full-speed USB 1.1 (12 Mbps) with separate 48 MHz USB clock domain.
// ============================================================================

interface usb_if (
    input logic clk,      // System clock (for UVM sync)
    input logic rst_n
);

    // USB PHY-level signals
    logic usb_clk;         // 48 MHz USB clock
    logic usb_rst_n;       // USB domain reset

    // D+ line (open-drain model)
    logic dp_i;            // TB → DUT (D+ input)
    logic dp_o;            // DUT → TB (D+ output)
    logic dp_oe;           // DUT output enable

    // D- line (open-drain model)
    logic dm_i;            // TB → DUT (D- input)
    logic dm_o;            // DUT → TB (D- output)
    logic dm_oe;           // DUT output enable

    // Resolved bus (wired-AND for open-drain)
    wire dp_bus = dp_oe ? dp_o : 1'b1;   // Pull-up default
    wire dm_bus = dm_oe ? dm_o : 1'b0;   // Pull-down default

    // Driver clocking block (TB drives device responses)
    clocking drv_cb @(posedge clk);
        default input #1 output #1;
        output dp_i;
        output dm_i;
        output usb_clk;
        output usb_rst_n;
        input  dp_o;
        input  dp_oe;
        input  dm_o;
        input  dm_oe;
    endclocking

    // Monitor clocking block (observes all signals)
    clocking mon_cb @(posedge clk);
        default input #1;
        input dp_i, dp_o, dp_oe;
        input dm_i, dm_o, dm_oe;
        input usb_clk, usb_rst_n;
    endclocking

    modport TB_SIDE  (output dp_i, dm_i, usb_clk, usb_rst_n,
                      input  dp_o, dp_oe, dm_o, dm_oe,
                      clocking drv_cb);
    modport MONITOR  (input  dp_i, dp_o, dp_oe, dm_i, dm_o, dm_oe,
                      input  usb_clk, usb_rst_n,
                      clocking mon_cb);

endinterface : usb_if
