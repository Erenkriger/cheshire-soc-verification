`ifndef JTAG_CONFIG_SV
`define JTAG_CONFIG_SV

// ============================================================================
// jtag_config.sv — JTAG Agent Configuration
// ============================================================================

class jtag_config extends uvm_object;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // Timing parameters
    int unsigned tck_period_ns = 20;   // 50 MHz JTAG clock (Cheshire default)

    // TAP parameters
    int unsigned ir_length = 5;        // RISC-V Debug Module IR length

    // JTAG IDCODE (Cheshire default: manufacturer=0x6d9, part=0xc5e5)
    bit [31:0] expected_idcode = 32'h1C5E5DB3;

    `uvm_object_utils_begin(jtag_config)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int(tck_period_ns,     UVM_ALL_ON)
        `uvm_field_int(ir_length,         UVM_ALL_ON)
        `uvm_field_int(expected_idcode,   UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "jtag_config");
        super.new(name);
    endfunction

endclass : jtag_config

`endif // JTAG_CONFIG_SV
