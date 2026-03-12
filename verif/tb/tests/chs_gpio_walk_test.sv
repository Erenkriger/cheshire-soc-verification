`ifndef CHS_GPIO_WALK_TEST_SV
`define CHS_GPIO_WALK_TEST_SV

// ============================================================================
// chs_gpio_walk_test.sv — GPIO Walking-Ones Test
// Drives walking-1 pattern across all 32 GPIO inputs.
// ============================================================================

class chs_gpio_walk_test extends chs_base_test;

    `uvm_component_utils(chs_gpio_walk_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        chs_gpio_walk_vseq vseq;

        `uvm_info(get_type_name(), "===== GPIO Walking-Ones Test START =====", UVM_LOW)

        vseq = chs_gpio_walk_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== GPIO Walking-Ones Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_gpio_walk_test

`endif
