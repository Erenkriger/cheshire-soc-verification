// ============================================================================
// chs_ral_soc_block.sv — Top-Level SoC Register Block (RAL)
//
// Aggregates all peripheral register sub-blocks into a single SoC
// register model with the correct base addresses:
//
//   UART  → 0x0300_2000
//   I2C   → 0x0300_3000
//   SPI   → 0x0300_4000
//   GPIO  → 0x0300_5000
// ============================================================================

`ifndef CHS_RAL_SOC_BLOCK_SV
`define CHS_RAL_SOC_BLOCK_SV

class chs_ral_soc_block extends uvm_reg_block;
    `uvm_object_utils(chs_ral_soc_block)

    // ─── Peripheral sub-blocks ───
    rand chs_ral_uart_block uart;
    rand chs_ral_spi_block  spi;
    rand chs_ral_i2c_block  i2c;
    rand chs_ral_gpio_block gpio;

    // ─── Top-level map ───
    uvm_reg_map soc_map;

    function new(string name = "chs_ral_soc_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        // Create peripheral sub-blocks
        uart = chs_ral_uart_block::type_id::create("uart");
        uart.configure(this, "");
        uart.build();

        spi = chs_ral_spi_block::type_id::create("spi");
        spi.configure(this, "");
        spi.build();

        i2c = chs_ral_i2c_block::type_id::create("i2c");
        i2c.configure(this, "");
        i2c.build();

        gpio = chs_ral_gpio_block::type_id::create("gpio");
        gpio.configure(this, "");
        gpio.build();

        // Create top-level SoC map
        // Base address 0x0 — sub-blocks provide the offsets
        soc_map = create_map("soc_map", 'h0, 4, UVM_LITTLE_ENDIAN);

        // Add sub-block maps at their respective base addresses
        soc_map.add_submap(uart.default_map, 'h0300_2000);
        soc_map.add_submap(spi.default_map,  'h0300_4000);
        soc_map.add_submap(i2c.default_map,  'h0300_3000);
        soc_map.add_submap(gpio.default_map, 'h0300_5000);

        lock_model();

        `uvm_info("RAL", "SoC register model built successfully", UVM_MEDIUM)
        `uvm_info("RAL", "  UART @ 0x03002000", UVM_MEDIUM)
        `uvm_info("RAL", "  SPI  @ 0x03004000", UVM_MEDIUM)
        `uvm_info("RAL", "  I2C  @ 0x03003000", UVM_MEDIUM)
        `uvm_info("RAL", "  GPIO @ 0x03005000", UVM_MEDIUM)
    endfunction
endclass

`endif // CHS_RAL_SOC_BLOCK_SV
