`ifndef CHS_VIRTUAL_SEQUENCER_SV
`define CHS_VIRTUAL_SEQUENCER_SV

// ============================================================================
// chs_virtual_sequencer.sv — Cheshire SoC Virtual Sequencer
// Provides handles to all sub-agent sequencers for coordinated
// system-level virtual sequences.
// ============================================================================

class chs_virtual_sequencer extends uvm_sequencer;

    // Sub-agent sequencer handles (set during connect_phase)
    jtag_sequencer m_jtag_sqr;
    uart_sequencer m_uart_sqr;
    spi_sequencer  m_spi_sqr;
    i2c_sequencer  m_i2c_sqr;
    gpio_sequencer m_gpio_sqr;

    `uvm_component_utils(chs_virtual_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : chs_virtual_sequencer

`endif // CHS_VIRTUAL_SEQUENCER_SV
