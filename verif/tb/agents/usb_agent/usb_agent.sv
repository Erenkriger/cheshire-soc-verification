// ============================================================================
// usb_agent.sv — USB 1.1 UVM Agent
// Configurable active/passive agent for USB OHCI verification.
// ============================================================================

`ifndef USB_AGENT_SV
`define USB_AGENT_SV

class usb_agent extends uvm_agent;

    usb_config     m_cfg;
    usb_driver     m_driver;
    usb_monitor    m_monitor;
    usb_sequencer  m_sequencer;

    uvm_analysis_port #(usb_transaction) ap;

    `uvm_component_utils(usb_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(usb_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "USB agent config not found")

        m_monitor = usb_monitor::type_id::create("m_monitor", this);

        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver    = usb_driver::type_id::create("m_driver", this);
            m_sequencer = usb_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        ap = m_monitor.ap;

        if (m_cfg.is_active == UVM_ACTIVE)
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    endfunction

endclass : usb_agent

`endif // USB_AGENT_SV
