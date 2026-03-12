`ifndef CHS_GPIO_TOGGLE_TEST_SV
`define CHS_GPIO_TOGGLE_TEST_SV

// ============================================================================
// chs_gpio_toggle_test.sv — GPIO Toggle Pattern Test
// Drives checkerboard, half-word, byte-boundary and all-1/0 patterns.
// ============================================================================

class chs_gpio_toggle_test extends chs_base_test;

    `uvm_component_utils(chs_gpio_toggle_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        chs_gpio_toggle_vseq vseq;

        `uvm_info(get_type_name(), "===== GPIO Toggle Test START =====", UVM_LOW)

        vseq = chs_gpio_toggle_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== GPIO Toggle Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_gpio_toggle_test

`endif
