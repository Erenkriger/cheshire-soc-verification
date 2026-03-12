// ============================================================================
// vga_config.sv — VGA Agent Configuration
// ============================================================================

`ifndef VGA_CONFIG_SV
`define VGA_CONFIG_SV

class vga_config extends uvm_object;

    // VGA is always passive (output-only from DUT)
    uvm_active_passive_enum is_active = UVM_PASSIVE;

    // Expected resolution (for frame tracking)
    int unsigned h_active  = 640;
    int unsigned v_active  = 480;
    int unsigned h_total   = 800;
    int unsigned v_total   = 525;

    `uvm_object_utils_begin(vga_config)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int(h_active, UVM_ALL_ON)
        `uvm_field_int(v_active, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "vga_config");
        super.new(name);
    endfunction

endclass : vga_config

`endif // VGA_CONFIG_SV
