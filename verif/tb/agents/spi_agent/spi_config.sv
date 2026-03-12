`ifndef SPI_CONFIG_SV
`define SPI_CONFIG_SV

// ============================================================================
// spi_config.sv — SPI Agent Configuration
// ============================================================================

class spi_config extends uvm_object;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // SPI protocol parameters
    bit        cpol = 0;                // Clock polarity (idle state of SCK)
    bit        cpha = 0;               // Clock phase (0=sample on leading, 1=trailing)
    int unsigned sck_period_ns = 100;  // SCK period in nanoseconds

    // SPI topology
    int unsigned num_cs = 2;           // Number of chip selects

    // Default SPI transfer mode
    spi_transaction::spi_mode_e mode = spi_transaction::SPI_STANDARD;

    // Driver timeout: if DUT SPI master doesn't assert CS within this time,
    // the driver completes the transaction with a warning.
    // Set to 0 to disable (wait forever).
    time driver_timeout = 500us;

    `uvm_object_utils_begin(spi_config)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int(cpol,                                UVM_ALL_ON)
        `uvm_field_int(cpha,                                UVM_ALL_ON)
        `uvm_field_int(sck_period_ns,                       UVM_ALL_ON)
        `uvm_field_int(num_cs,                              UVM_ALL_ON)
        `uvm_field_enum(spi_transaction::spi_mode_e, mode,  UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "spi_config");
        super.new(name);
    endfunction

endclass : spi_config

`endif // SPI_CONFIG_SV
