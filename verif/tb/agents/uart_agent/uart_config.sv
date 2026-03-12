`ifndef UART_CONFIG_SV
`define UART_CONFIG_SV

// ============================================================================
// uart_config.sv — UART Agent Configuration
// ============================================================================

class uart_config extends uvm_object;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    int unsigned baud_rate    = 115200;  // Cheshire default
    bit          parity_en    = 0;       // Cheshire default: no parity
    bit          parity_even  = 1;
    int unsigned data_bits    = 8;
    int unsigned stop_bits    = 1;
    int unsigned clk_freq_hz  = 50_000_000;  // 50 MHz system clock

    `uvm_object_utils_begin(uart_config)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int(baud_rate,    UVM_ALL_ON)
        `uvm_field_int(parity_en,    UVM_ALL_ON)
        `uvm_field_int(parity_even,  UVM_ALL_ON)
        `uvm_field_int(data_bits,    UVM_ALL_ON)
        `uvm_field_int(stop_bits,    UVM_ALL_ON)
        `uvm_field_int(clk_freq_hz,  UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "uart_config");
        super.new(name);
    endfunction

    // Calculate bit period in ns
    function int unsigned get_bit_period_ns();
        return 1_000_000_000 / baud_rate;
    endfunction

endclass : uart_config

`endif // UART_CONFIG_SV
