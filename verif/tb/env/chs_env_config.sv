`ifndef CHS_ENV_CONFIG_SV
`define CHS_ENV_CONFIG_SV

// ============================================================================
// chs_env_config.sv — Cheshire SoC Environment Configuration
// ============================================================================

class chs_env_config extends uvm_object;

    // ---------- Agent enable flags ----------
    bit has_jtag_agent = 1;
    bit has_uart_agent = 1;
    bit has_spi_agent  = 1;
    bit has_i2c_agent  = 1;
    bit has_gpio_agent = 1;
    bit has_axi_agent  = 1;  // AXI LLC/DRAM port monitor (passive)

    // ---------- Sub-agent configuration handles ----------
    jtag_config m_jtag_cfg;
    uart_config m_uart_cfg;
    spi_config  m_spi_cfg;
    i2c_config  m_i2c_cfg;
    gpio_config m_gpio_cfg;

    // ---------- RAL enable ----------
    bit has_ral = 0;

    // ---------- SoC-level parameters ----------
    // Boot mode: 0=JTAG, 1=SerialLink, 2=UART
    logic [1:0] boot_mode = 2'b00;

    `uvm_object_utils_begin(chs_env_config)
        `uvm_field_int(has_jtag_agent,  UVM_ALL_ON)
        `uvm_field_int(has_uart_agent,  UVM_ALL_ON)
        `uvm_field_int(has_spi_agent,   UVM_ALL_ON)
        `uvm_field_int(has_i2c_agent,   UVM_ALL_ON)
        `uvm_field_int(has_gpio_agent,  UVM_ALL_ON)
        `uvm_field_int(has_axi_agent,   UVM_ALL_ON)
        `uvm_field_int(has_ral,         UVM_ALL_ON)
        `uvm_field_object(m_jtag_cfg,   UVM_ALL_ON)
        `uvm_field_object(m_uart_cfg,   UVM_ALL_ON)
        `uvm_field_object(m_spi_cfg,    UVM_ALL_ON)
        `uvm_field_object(m_i2c_cfg,    UVM_ALL_ON)
        `uvm_field_object(m_gpio_cfg,   UVM_ALL_ON)
        `uvm_field_int(boot_mode,       UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "chs_env_config");
        super.new(name);
    endfunction

endclass : chs_env_config

`endif // CHS_ENV_CONFIG_SV
