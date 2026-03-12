`ifndef JTAG_AGENT_SV
`define JTAG_AGENT_SV

// ============================================================================
// jtag_agent.sv — JTAG UVM Agent
// ============================================================================

class jtag_agent extends uvm_agent;

    jtag_config     m_cfg;
    jtag_driver     m_driver;
    jtag_monitor    m_monitor;
    jtag_sequencer  m_sequencer;

    uvm_analysis_port #(jtag_transaction) ap;
    uvm_analysis_port #(jtag_transaction) drv_ap;  // Driver-side port for coverage

    `uvm_component_utils(jtag_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(jtag_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "JTAG config not found")

        m_monitor = jtag_monitor::type_id::create("m_monitor", this);

        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver    = jtag_driver::type_id::create("m_driver", this);
            m_sequencer = jtag_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = m_monitor.ap;

        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
            drv_ap = m_driver.drv_ap;
        end
    endfunction

endclass : jtag_agent

`endif // JTAG_AGENT_SV
