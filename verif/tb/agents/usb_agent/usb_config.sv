// ============================================================================
// usb_config.sv — USB Agent Configuration
// ============================================================================

`ifndef USB_CONFIG_SV
`define USB_CONFIG_SV

class usb_config extends uvm_object;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // USB speed: 0=Low-speed (1.5Mbps), 1=Full-speed (12Mbps)
    bit full_speed = 1;

    // USB clock period (48 MHz = ~20.83ns)
    int unsigned usb_clk_period_ns = 21;

    `uvm_object_utils_begin(usb_config)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int(full_speed, UVM_ALL_ON)
        `uvm_field_int(usb_clk_period_ns, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "usb_config");
        super.new(name);
    endfunction

endclass : usb_config

`endif // USB_CONFIG_SV
