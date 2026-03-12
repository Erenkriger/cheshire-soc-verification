`ifndef CHS_ENV_SV
`define CHS_ENV_SV

// ============================================================================
// chs_env.sv — Cheshire SoC UVM Environment
// Top-level environment that instantiates all agents, scoreboard,
// coverage collector, and virtual sequencer.
// ============================================================================

class chs_env extends uvm_env;

    // ---------- Configuration ----------
    chs_env_config m_env_cfg;

    // ---------- Agents ----------
    jtag_agent  m_jtag_agent;
    uart_agent  m_uart_agent;
    spi_agent   m_spi_agent;
    i2c_agent   m_i2c_agent;
    gpio_agent  m_gpio_agent;
    chs_axi_agent m_axi_agent;  // AXI LLC/DRAM port passive monitor
    slink_agent m_slink_agent;  // Serial Link agent
    vga_agent   m_vga_agent;    // VGA output monitor (passive)
    usb_agent   m_usb_agent;    // USB 1.1 OHCI agent

    // ---------- Infrastructure ----------
    chs_scoreboard        m_scoreboard;
    chs_coverage          m_coverage;
    chs_virtual_sequencer m_virt_sqr;

    // ---------- RAL (Register Abstraction Layer) ----------
    chs_ral_soc_block     m_ral_model;
    chs_ral_adapter       m_ral_adapter;

    `uvm_component_utils(chs_env)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ========================== Build Phase ==========================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Retrieve environment configuration
        if (!uvm_config_db#(chs_env_config)::get(this, "", "m_env_cfg", m_env_cfg))
            `uvm_fatal("NOCFG", "Cheshire env config (m_env_cfg) not found in config_db")

        // ---- Create agents conditionally ----

        if (m_env_cfg.has_jtag_agent) begin
            uvm_config_db#(jtag_config)::set(this, "m_jtag_agent*", "m_cfg",
                m_env_cfg.m_jtag_cfg);
            m_jtag_agent = jtag_agent::type_id::create("m_jtag_agent", this);
        end

        if (m_env_cfg.has_uart_agent) begin
            uvm_config_db#(uart_config)::set(this, "m_uart_agent*", "m_cfg",
                m_env_cfg.m_uart_cfg);
            m_uart_agent = uart_agent::type_id::create("m_uart_agent", this);
        end

        if (m_env_cfg.has_spi_agent) begin
            uvm_config_db#(spi_config)::set(this, "m_spi_agent*", "m_cfg",
                m_env_cfg.m_spi_cfg);
            m_spi_agent = spi_agent::type_id::create("m_spi_agent", this);
        end

        if (m_env_cfg.has_i2c_agent) begin
            uvm_config_db#(i2c_config)::set(this, "m_i2c_agent*", "m_cfg",
                m_env_cfg.m_i2c_cfg);
            m_i2c_agent = i2c_agent::type_id::create("m_i2c_agent", this);
        end

        if (m_env_cfg.has_gpio_agent) begin
            uvm_config_db#(gpio_config)::set(this, "m_gpio_agent*", "m_cfg",
                m_env_cfg.m_gpio_cfg);
            m_gpio_agent = gpio_agent::type_id::create("m_gpio_agent", this);
        end

        if (m_env_cfg.has_axi_agent) begin
            m_axi_agent = chs_axi_agent::type_id::create("m_axi_agent", this);
            m_axi_agent.is_active = UVM_PASSIVE;  // SoC-level: passive only
        end

        if (m_env_cfg.has_slink_agent) begin
            uvm_config_db#(slink_config)::set(this, "m_slink_agent*", "m_cfg",
                m_env_cfg.m_slink_cfg);
            m_slink_agent = slink_agent::type_id::create("m_slink_agent", this);
        end

        if (m_env_cfg.has_vga_agent) begin
            uvm_config_db#(vga_config)::set(this, "m_vga_agent*", "m_cfg",
                m_env_cfg.m_vga_cfg);
            m_vga_agent = vga_agent::type_id::create("m_vga_agent", this);
        end

        if (m_env_cfg.has_usb_agent) begin
            uvm_config_db#(usb_config)::set(this, "m_usb_agent*", "m_cfg",
                m_env_cfg.m_usb_cfg);
            m_usb_agent = usb_agent::type_id::create("m_usb_agent", this);
        end

        // ---- Create scoreboard, coverage, virtual sequencer ----
        m_scoreboard = chs_scoreboard::type_id::create("m_scoreboard", this);
        m_coverage   = chs_coverage::type_id::create("m_coverage", this);
        m_virt_sqr   = chs_virtual_sequencer::type_id::create("m_virt_sqr", this);

        // Propagate env config to coverage collector
        uvm_config_db#(chs_env_config)::set(this, "m_coverage", "m_env_cfg", m_env_cfg);

        // ---- Create RAL model & adapter (if enabled) ----
        if (m_env_cfg.has_ral) begin
            m_ral_model = chs_ral_soc_block::type_id::create("m_ral_model");
            m_ral_model.build();

            m_ral_adapter = chs_ral_adapter::type_id::create("m_ral_adapter");

            // Publish RAL model via config_db for tests/sequences
            uvm_config_db#(chs_ral_soc_block)::set(this, "*", "m_ral_model", m_ral_model);
        end
    endfunction

    // ========================== Connect Phase ==========================
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // ---- Connect agent analysis ports → scoreboard & coverage ----

        if (m_env_cfg.has_jtag_agent) begin
            m_jtag_agent.ap.connect(m_scoreboard.jtag_imp);
            m_jtag_agent.ap.connect(m_coverage.jtag_imp);
            if (m_jtag_agent.m_cfg.is_active == UVM_ACTIVE)
                m_virt_sqr.m_jtag_sqr = m_jtag_agent.m_sequencer;
        end

        if (m_env_cfg.has_uart_agent) begin
            m_uart_agent.ap.connect(m_scoreboard.uart_imp);
            m_uart_agent.ap.connect(m_coverage.uart_imp);
            if (m_uart_agent.m_cfg.is_active == UVM_ACTIVE)
                m_virt_sqr.m_uart_sqr = m_uart_agent.m_sequencer;
        end

        if (m_env_cfg.has_spi_agent) begin
            m_spi_agent.ap.connect(m_scoreboard.spi_imp);
            m_spi_agent.ap.connect(m_coverage.spi_imp);
            if (m_spi_agent.m_cfg.is_active == UVM_ACTIVE)
                m_virt_sqr.m_spi_sqr = m_spi_agent.m_sequencer;
        end

        if (m_env_cfg.has_i2c_agent) begin
            m_i2c_agent.ap.connect(m_scoreboard.i2c_imp);
            m_i2c_agent.ap.connect(m_coverage.i2c_imp);
            if (m_i2c_agent.m_cfg.is_active == UVM_ACTIVE)
                m_virt_sqr.m_i2c_sqr = m_i2c_agent.m_sequencer;
        end

        if (m_env_cfg.has_gpio_agent) begin
            m_gpio_agent.ap.connect(m_scoreboard.gpio_imp);
            m_gpio_agent.ap.connect(m_coverage.gpio_imp);
            if (m_gpio_agent.m_cfg.is_active == UVM_ACTIVE)
                m_virt_sqr.m_gpio_sqr = m_gpio_agent.m_sequencer;
        end

        if (m_env_cfg.has_axi_agent) begin
            m_axi_agent.ap.connect(m_scoreboard.axi_imp);
            m_axi_agent.ap.connect(m_coverage.axi_imp);
            `uvm_info("ENV", "AXI LLC monitor connected to scoreboard & coverage", UVM_MEDIUM)
        end

        if (m_env_cfg.has_slink_agent) begin
            if (m_slink_agent.m_cfg.is_active == UVM_ACTIVE)
                m_virt_sqr.m_slink_sqr = m_slink_agent.m_sequencer;
            `uvm_info("ENV", "Serial Link agent connected", UVM_MEDIUM)
        end

        if (m_env_cfg.has_vga_agent) begin
            `uvm_info("ENV", "VGA passive monitor connected", UVM_MEDIUM)
        end

        if (m_env_cfg.has_usb_agent) begin
            if (m_usb_agent.m_cfg.is_active == UVM_ACTIVE)
                m_virt_sqr.m_usb_sqr = m_usb_agent.m_sequencer;
            `uvm_info("ENV", "USB 1.1 agent connected", UVM_MEDIUM)
        end

        // ---- Connect RAL to JTAG sequencer ----
        if (m_env_cfg.has_ral && m_env_cfg.has_jtag_agent) begin
            if (m_ral_model != null && m_virt_sqr.m_jtag_sqr != null) begin
                m_ral_model.soc_map.set_sequencer(m_virt_sqr.m_jtag_sqr, m_ral_adapter);
                m_ral_model.soc_map.set_auto_predict(1);
                `uvm_info("ENV", "RAL model connected to JTAG sequencer via SBA adapter", UVM_MEDIUM)
            end
        end
    endfunction

endclass : chs_env

`endif // CHS_ENV_SV
