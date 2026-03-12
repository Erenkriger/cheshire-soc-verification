`ifndef CHS_GPIO_TOGGLE_VSEQ_SV
`define CHS_GPIO_TOGGLE_VSEQ_SV

// ============================================================================
// chs_gpio_toggle_vseq.sv — GPIO Toggle Pattern Virtual Sequence
// Drives alternating patterns on GPIO inputs:
//   1. 0x55555555 / 0xAAAAAAAA (checkerboard)
//   2. 0x0000FFFF / 0xFFFF0000 (half-word boundaries)
//   3. 0x00FF00FF / 0xFF00FF00 (byte boundaries)
// ============================================================================

class chs_gpio_toggle_vseq extends uvm_sequence;

    `uvm_object_utils(chs_gpio_toggle_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_gpio_toggle_vseq");
        super.new(name);
    endfunction

    virtual task body();
        gpio_base_seq gpio_seq;

        `uvm_info(get_type_name(),
                  "===== GPIO Toggle Pattern START =====", UVM_LOW)

        gpio_seq = gpio_base_seq::type_id::create("gpio_seq");

        // Checkerboard
        `uvm_info(get_type_name(), "Phase 1: Checkerboard pattern", UVM_MEDIUM)
        gpio_seq.drive_all(32'h5555_5555, p_sequencer.m_gpio_sqr);
        gpio_seq.drive_all(32'hAAAA_AAAA, p_sequencer.m_gpio_sqr);

        // Half-word boundaries
        `uvm_info(get_type_name(), "Phase 2: Half-word pattern", UVM_MEDIUM)
        gpio_seq.drive_all(32'h0000_FFFF, p_sequencer.m_gpio_sqr);
        gpio_seq.drive_all(32'hFFFF_0000, p_sequencer.m_gpio_sqr);

        // Byte boundaries
        `uvm_info(get_type_name(), "Phase 3: Byte-boundary pattern", UVM_MEDIUM)
        gpio_seq.drive_all(32'h00FF_00FF, p_sequencer.m_gpio_sqr);
        gpio_seq.drive_all(32'hFF00_FF00, p_sequencer.m_gpio_sqr);

        // All ones, all zeros
        `uvm_info(get_type_name(), "Phase 4: All-1 / All-0", UVM_MEDIUM)
        gpio_seq.drive_all(32'hFFFF_FFFF, p_sequencer.m_gpio_sqr);
        gpio_seq.drive_all(32'h0000_0000, p_sequencer.m_gpio_sqr);

        `uvm_info(get_type_name(),
                  "===== GPIO Toggle Pattern COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_gpio_toggle_vseq

`endif
