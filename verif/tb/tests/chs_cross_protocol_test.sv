`ifndef CHS_CROSS_PROTOCOL_TEST_SV
`define CHS_CROSS_PROTOCOL_TEST_SV

// ============================================================================
// chs_cross_protocol_test.sv — Cross-Protocol Closed-Loop Test (Aşama 4)
//
// Exercises all peripherals (GPIO, UART, SPI) in a single test with
// scoreboard data verification. This is the key system-level test that
// validates the full SoC path for each peripheral.
//
// Timeout: 100ms — long because multiple peripherals with slow JTAG/SBA path
// ============================================================================

class chs_cross_protocol_test extends chs_base_test;

    `uvm_component_utils(chs_cross_protocol_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 100ms;
    endfunction

    virtual task test_body();
        chs_cross_protocol_vseq vseq;

        `uvm_info(get_type_name(),
            "========== Cross-Protocol Closed-Loop Test (Aşama 4) ==========", UVM_LOW)
        `uvm_info(get_type_name(),
            "Testing: GPIO + UART + SPI closed-loop with scoreboard verification", UVM_LOW)

        vseq = chs_cross_protocol_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
            "========== Cross-Protocol Test Complete ==========", UVM_LOW)
    endtask : test_body

endclass : chs_cross_protocol_test

`endif // CHS_CROSS_PROTOCOL_TEST_SV
