`ifndef I2C_AGENT_SV
`define I2C_AGENT_SV

// ============================================================================
// i2c_agent.sv — I2C UVM Agent
// Acts as I2C slave — the DUT (Cheshire I2C Host) is the master
// ============================================================================

class i2c_agent extends uvm_agent;

    i2c_config     m_cfg;
    i2c_driver     m_driver;
    i2c_monitor    m_monitor;
    i2c_sequencer  m_sequencer;

    uvm_analysis_port #(i2c_transaction) ap;

    `uvm_component_utils(i2c_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(i2c_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "I2C config not found")

        m_monitor = i2c_monitor::type_id::create("m_monitor", this);

        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver    = i2c_driver::type_id::create("m_driver", this);
            m_sequencer = i2c_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = m_monitor.ap;

        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction

endclass : i2c_agent

`endif // I2C_AGENT_SV
