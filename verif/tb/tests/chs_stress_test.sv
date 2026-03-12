`ifndef CHS_STRESS_TEST_SV
`define CHS_STRESS_TEST_SV

// ============================================================================
// chs_stress_test.sv — Peripheral Stress Test (Aşama 4)
//
// Rapidly alternates SBA operations across GPIO, UART, SPI to verify
// AXI crossbar integrity and peripheral independence.
//
// Timeout: 100ms — multiple rounds of multi-peripheral operations
// ============================================================================

class chs_stress_test extends chs_base_test;

    `uvm_component_utils(chs_stress_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 100ms;
    endfunction

    virtual task test_body();
        chs_stress_vseq vseq;

        `uvm_info(get_type_name(),
            "========== Peripheral Stress Test (Aşama 4) ==========", UVM_LOW)
        `uvm_info(get_type_name(),
            "Testing: Rapid round-robin GPIO→UART→SPI across AXI crossbar", UVM_LOW)

        vseq = chs_stress_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
            "========== Peripheral Stress Test Complete ==========", UVM_LOW)
    endtask : test_body

endclass : chs_stress_test

`endif // CHS_STRESS_TEST_SV
