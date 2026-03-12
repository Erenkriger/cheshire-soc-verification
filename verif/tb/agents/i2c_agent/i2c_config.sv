`ifndef I2C_CONFIG_SV
`define I2C_CONFIG_SV

// ============================================================================
// i2c_config.sv — I2C Agent Configuration
// ============================================================================

class i2c_config extends uvm_object;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // I2C slave parameters
    bit [6:0]    slave_address = 7'h50;    // Default EEPROM address (24FC1025)
    int unsigned scl_frequency = 100000;   // 100 kHz standard mode
    bit          stretch_en   = 1'b0;      // Enable clock stretching

    // Driver timeout: if DUT I2C master doesn't generate START within this
    // time, the driver completes the transaction with a warning.
    // Set to 0 to disable (wait forever).
    time driver_timeout = 500us;

    `uvm_object_utils_begin(i2c_config)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int(slave_address,                        UVM_ALL_ON)
        `uvm_field_int(scl_frequency,                        UVM_ALL_ON)
        `uvm_field_int(stretch_en,                           UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "i2c_config");
        super.new(name);
    endfunction

    // Calculate SCL half-period in nanoseconds
    function int unsigned get_scl_half_period_ns();
        return (1_000_000_000 / scl_frequency) / 2;
    endfunction

endclass : i2c_config

`endif // I2C_CONFIG_SV
