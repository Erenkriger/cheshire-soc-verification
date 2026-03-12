`ifndef CHS_GPIO_WALK_VSEQ_SV
`define CHS_GPIO_WALK_VSEQ_SV

// ============================================================================
// chs_gpio_walk_vseq.sv — GPIO Walking-Ones Virtual Sequence
// Drives a walking-1 pattern across all 32 GPIO input pins.
// Each step sets exactly one bit high, cycling through bit 0 to 31.
// ============================================================================

class chs_gpio_walk_vseq extends uvm_sequence;

    `uvm_object_utils(chs_gpio_walk_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_gpio_walk_vseq");
        super.new(name);
    endfunction

    virtual task body();
        gpio_base_seq gpio_seq;

        `uvm_info(get_type_name(),
                  "===== GPIO Walking-Ones START =====", UVM_LOW)

        gpio_seq = gpio_base_seq::type_id::create("gpio_seq");

        // Walk a 1 through all 32 bits
        for (int i = 0; i < 32; i++) begin
            gpio_seq.drive_all(32'h1 << i, p_sequencer.m_gpio_sqr);
            `uvm_info(get_type_name(),
                      $sformatf("Walking-1: bit[%0d] = 0x%08h", i, 32'h1 << i), UVM_HIGH)
        end

        // Return to idle
        gpio_seq.drive_all(32'h0, p_sequencer.m_gpio_sqr);

        `uvm_info(get_type_name(),
                  "===== GPIO Walking-Ones COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_gpio_walk_vseq

`endif
