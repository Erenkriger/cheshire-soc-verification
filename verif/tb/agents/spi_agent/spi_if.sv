// ============================================================================
// spi_if.sv — SPI Interface (Quad-SPI, OpenTitan SPI Host)
// Cheshire SPI Host ports: spih_sck_o, spih_csb_o[NumCs-1:0],
//   spih_sd_o[3:0], spih_sd_en_o[3:0], spih_sd_i[3:0]
// ============================================================================

interface spi_if (
    input logic clk,
    input logic rst_n
);

    logic           sck;          // SPI clock (driven by DUT master)
    logic [1:0]     csb;          // Chip select (active low, up to 2 CS)
    logic [3:0]     sd_o;         // Data out from DUT master (MOSI in standard)
    logic [3:0]     sd_en;        // Output enable for sd_o
    logic [3:0]     sd_i;         // Data in to DUT master (MISO in standard)

    // Clocking block for slave driver (responds on SCK edges)
    clocking drv_cb @(posedge sck);
        default input #1 output #1;
        input  sd_o;
        input  sd_en;
        input  csb;
        output sd_i;
    endclocking

    // Clocking block for monitor
    clocking mon_cb @(posedge sck);
        default input #1;
        input sd_o;
        input sd_en;
        input sd_i;
        input csb;
    endclocking

    modport MASTER  (output sck, output csb, output sd_o, output sd_en, input sd_i);
    modport SLAVE   (input sck, input csb, input sd_o, input sd_en, output sd_i,
                     clocking drv_cb);
    modport MONITOR (input sck, input csb, input sd_o, input sd_en, input sd_i,
                     clocking mon_cb);

endinterface : spi_if
