`ifndef UART_AGENT_SV
`define UART_AGENT_SV

// ============================================================================
// uart_agent.sv — UART UVM Agent
// ============================================================================

class uart_agent extends uvm_agent;

    uart_config     m_cfg;
    uart_driver     m_driver;
    uart_monitor    m_monitor;
    uart_sequencer  m_sequencer;

    uvm_analysis_port #(uart_transaction) ap;

    `uvm_component_utils(uart_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(uart_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "UART config not found")

        m_monitor = uart_monitor::type_id::create("m_monitor", this);

        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver    = uart_driver::type_id::create("m_driver", this);
            m_sequencer = uart_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = m_monitor.ap;

        if (m_cfg.is_active == UVM_ACTIVE)
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    endfunction

endclass : uart_agent

`endif // UART_AGENT_SV
