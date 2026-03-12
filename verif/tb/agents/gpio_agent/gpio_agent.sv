`ifndef GPIO_AGENT_SV
`define GPIO_AGENT_SV

// ============================================================================
// gpio_agent.sv — GPIO UVM Agent
// ============================================================================

class gpio_agent extends uvm_agent;

    gpio_config     m_cfg;
    gpio_driver     m_driver;
    gpio_monitor    m_monitor;
    gpio_sequencer  m_sequencer;

    uvm_analysis_port #(gpio_transaction) ap;

    `uvm_component_utils(gpio_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(gpio_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "GPIO config not found")

        m_monitor = gpio_monitor::type_id::create("m_monitor", this);

        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver    = gpio_driver::type_id::create("m_driver", this);
            m_sequencer = gpio_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = m_monitor.ap;

        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction

endclass : gpio_agent

`endif // GPIO_AGENT_SV
