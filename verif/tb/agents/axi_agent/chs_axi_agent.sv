`ifndef CHS_AXI_AGENT_SV
`define CHS_AXI_AGENT_SV

// ============================================================================
// chs_axi_agent.sv — AXI4 UVM Agent (Passive Mode)
//
// At SoC level, this agent operates in PASSIVE mode only.
// The CPU core (CVA6) and DMA engine generate AXI traffic naturally.
// We only observe and analyze — no driving.
//
// Reusability: When porting to IP-level verification, this agent can
// be extended with a driver and sequencer for ACTIVE mode.
// ============================================================================

class chs_axi_agent extends uvm_agent;

    `uvm_component_utils(chs_axi_agent)

    chs_axi_monitor            m_monitor;
    uvm_analysis_port #(chs_axi_seq_item)  ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Always create monitor (passive observation)
        m_monitor = chs_axi_monitor::type_id::create("m_monitor", this);
        ap = new("ap", this);

        if (is_active == UVM_ACTIVE) begin
            `uvm_info("AXI_AGT", "Agent is ACTIVE — driver/sequencer would be created for IP-level reuse", UVM_LOW)
            // For SoC-level, we stay passive. Future extension point.
        end

        `uvm_info("AXI_AGT", $sformatf("AXI Agent created (mode=%s)", is_active.name()), UVM_LOW)
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = m_monitor.ap;
    endfunction

endclass : chs_axi_agent

`endif // CHS_AXI_AGENT_SV
