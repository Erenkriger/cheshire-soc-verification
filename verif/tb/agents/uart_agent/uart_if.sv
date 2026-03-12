// ============================================================================
// uart_if.sv — UART Interface
// Cheshire's UART is TI 16750 compatible: uart_tx_o, uart_rx_i + modem ctrl
// ============================================================================

interface uart_if (
    input logic clk,
    input logic rst_n
);

    logic tx;        // DUT → TB (DUT transmits)
    logic rx;        // TB → DUT (TB transmits to DUT)

    // Modem control (directly tied off in most configs)
    logic rts_n;
    logic dtr_n;
    logic cts_n;
    logic dsr_n;
    logic dcd_n;
    logic rin_n;

    modport DUT_SIDE (output tx, input rx, output rts_n, output dtr_n,
                      input cts_n, input dsr_n, input dcd_n, input rin_n);
    modport TB_SIDE  (input tx, output rx, input rts_n, input dtr_n,
                      output cts_n, output dsr_n, output dcd_n, output rin_n);
    modport MONITOR  (input tx, input rx, input rts_n, input dtr_n,
                      input cts_n, input dsr_n, input dcd_n, input rin_n);

endinterface : uart_if
