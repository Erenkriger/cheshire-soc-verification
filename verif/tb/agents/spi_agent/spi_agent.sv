`ifndef SPI_AGENT_SV
`define SPI_AGENT_SV

// ============================================================================
// spi_agent.sv — SPI UVM Agent
// Acts as SPI slave — the DUT (Cheshire SPI Host) is the master
// ============================================================================

class spi_agent extends uvm_agent;

    spi_config     m_cfg;
    spi_driver     m_driver;
    spi_monitor    m_monitor;
    spi_sequencer  m_sequencer;

    uvm_analysis_port #(spi_transaction) ap;

    `uvm_component_utils(spi_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(spi_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "SPI config not found")

        m_monitor = spi_monitor::type_id::create("m_monitor", this);

        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver    = spi_driver::type_id::create("m_driver", this);
            m_sequencer = spi_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = m_monitor.ap;

        if (m_cfg.is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction

endclass : spi_agent

`endif // SPI_AGENT_SV
