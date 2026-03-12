// ============================================================================
// slink_agent.sv — Serial Link UVM Agent
// Configurable active/passive agent for chip-to-chip serial link.
// ============================================================================

`ifndef SLINK_AGENT_SV
`define SLINK_AGENT_SV

class slink_agent extends uvm_agent;

    slink_config     m_cfg;
    slink_driver     m_driver;
    slink_monitor    m_monitor;
    slink_sequencer  m_sequencer;

    uvm_analysis_port #(slink_transaction) ap;

    `uvm_component_utils(slink_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(slink_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "Serial Link agent config not found")

        m_monitor = slink_monitor::type_id::create("m_monitor", this);

        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver    = slink_driver::type_id::create("m_driver", this);
            m_sequencer = slink_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        ap = m_monitor.ap;

        if (m_cfg.is_active == UVM_ACTIVE)
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    endfunction

endclass : slink_agent

`endif // SLINK_AGENT_SV
