`ifndef GPIO_CONFIG_SV
`define GPIO_CONFIG_SV

// ============================================================================
// gpio_config.sv — GPIO Agent Configuration
// ============================================================================

class gpio_config extends uvm_object;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // GPIO width (OpenTitan GPIO in Cheshire is 32-bit)
    int unsigned width = 32;

    `uvm_object_utils_begin(gpio_config)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int(width, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "gpio_config");
        super.new(name);
    endfunction

endclass : gpio_config

`endif // GPIO_CONFIG_SV
