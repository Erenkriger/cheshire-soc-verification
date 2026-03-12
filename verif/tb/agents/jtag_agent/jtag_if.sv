// ============================================================================
// jtag_if.sv — JTAG TAP Interface (IEEE 1149.1)
// Cheshire uses JTAG for RISC-V Debug Module access + System Bus Access
// ============================================================================

interface jtag_if (
    input logic clk,
    input logic rst_n
);

    logic tck;
    logic tms;
    logic tdi;
    logic tdo;
    logic tdo_oe;
    logic trst_n;

    // Driver clocking block (master drives TCK, TMS, TDI)
    clocking drv_cb @(posedge tck);
        default input #1 output #1;
        output tms;
        output tdi;
        output trst_n;
        input  tdo;
    endclocking

    // Monitor clocking block
    clocking mon_cb @(posedge tck);
        default input #1;
        input tms;
        input tdi;
        input tdo;
        input trst_n;
    endclocking

    modport MASTER  (clocking drv_cb, output tck, output trst_n);
    modport MONITOR (clocking mon_cb, input tck, input trst_n);

endinterface : jtag_if
