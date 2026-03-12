// ============================================================================
// vga_agent.sv — VGA UVM Agent (Passive Only)
// VGA is output-only from DUT, so this agent is always passive.
// ============================================================================

`ifndef VGA_AGENT_SV
`define VGA_AGENT_SV

class vga_agent extends uvm_agent;

    vga_config   m_cfg;
    vga_monitor  m_monitor;

    uvm_analysis_port #(vga_transaction) ap;

    `uvm_component_utils(vga_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(vga_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "VGA agent config not found")

        m_monitor = vga_monitor::type_id::create("m_monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = m_monitor.ap;
    endfunction

endclass : vga_agent

`endif // VGA_AGENT_SV
