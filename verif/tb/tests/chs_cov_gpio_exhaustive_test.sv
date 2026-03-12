// ============================================================================
// chs_cov_gpio_exhaustive_test.sv — GPIO Exhaustive Coverage Test
// ============================================================================

`ifndef CHS_COV_GPIO_EXHAUSTIVE_TEST_SV
`define CHS_COV_GPIO_EXHAUSTIVE_TEST_SV

class chs_cov_gpio_exhaustive_test extends chs_base_test;

    `uvm_component_utils(chs_cov_gpio_exhaustive_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 100ms;
    endfunction

    virtual task test_body();
        chs_cov_gpio_exhaustive_vseq vseq;

        `uvm_info(get_type_name(),
            "========== GPIO Exhaustive Coverage Test ==========", UVM_LOW)
        `uvm_info(get_type_name(),
            "Targets: All OE bins, data patterns, transitions, cross", UVM_LOW)

        vseq = chs_cov_gpio_exhaustive_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
            "========== GPIO Exhaustive Coverage Complete ==========", UVM_LOW)
    endtask : test_body

endclass : chs_cov_gpio_exhaustive_test

`endif // CHS_COV_GPIO_EXHAUSTIVE_TEST_SV
