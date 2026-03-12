`ifndef CHS_GPIO_DEEP_TEST_SV
`define CHS_GPIO_DEEP_TEST_SV

// ============================================================================
// chs_gpio_deep_test.sv — Deep GPIO SBA Test
//
// Exercises advanced GPIO features via JTAG SBA:
//   - Walking-1 output patterns
//   - Masked output writes (MASKED_OUT_LOWER/UPPER)
//   - Input data sampling via DATA_IN
//   - Interrupt register configuration and INTR_TEST
//   - Granular output enable control (MASKED_OE)
//
// Timeout: 50ms — many SBA operations through JTAG
// ============================================================================

class chs_gpio_deep_test extends chs_base_test;

    `uvm_component_utils(chs_gpio_deep_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 50ms;
    endfunction

    virtual task test_body();
        chs_gpio_deep_vseq vseq;

        `uvm_info(get_type_name(),
                  "========== Deep GPIO SBA Test ==========", UVM_LOW)
        `uvm_info(get_type_name(),
                  "Testing: Walking-1, Masked Output, Interrupts, OE Control", UVM_LOW)

        vseq = chs_gpio_deep_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
                  "========== Deep GPIO SBA Test Complete ==========", UVM_LOW)
    endtask : test_body

endclass : chs_gpio_deep_test

`endif // CHS_GPIO_DEEP_TEST_SV
