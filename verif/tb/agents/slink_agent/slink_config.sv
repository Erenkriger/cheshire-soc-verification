// ============================================================================
// slink_config.sv — Serial Link Agent Configuration
// ============================================================================

`ifndef SLINK_CONFIG_SV
`define SLINK_CONFIG_SV

class slink_config extends uvm_object;

    uvm_active_passive_enum is_active = UVM_ACTIVE;
    int unsigned num_channels = 1;
    int unsigned num_lanes    = 4;

    `uvm_object_utils_begin(slink_config)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int(num_channels, UVM_ALL_ON)
        `uvm_field_int(num_lanes,    UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "slink_config");
        super.new(name);
    endfunction

endclass : slink_config

`endif // SLINK_CONFIG_SV
