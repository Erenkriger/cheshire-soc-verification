// ============================================================================
// chs_concurrent_test.sv — Multi-Peripheral Concurrent Access Test
//
// Aşama 6: Stress-tests the AXI crossbar by rapidly accessing
// GPIO, UART, SPI, and I2C in interleaved round-robin fashion.
// ============================================================================

`ifndef CHS_CONCURRENT_TEST_SV
`define CHS_CONCURRENT_TEST_SV

class chs_concurrent_test extends chs_base_test;

    `uvm_component_utils(chs_concurrent_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 100ms;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "========== Concurrent Multi-Peripheral Test ==========", UVM_LOW)
        `uvm_info(get_type_name(), "Testing: Rapid interleaved SBA access to 4 peripherals", UVM_LOW)
    endfunction

    virtual task test_body();
        chs_concurrent_vseq vseq;
        vseq = chs_concurrent_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);
        `uvm_info(get_type_name(), "========== Concurrent Test Complete ==========", UVM_LOW)
    endtask

endclass

`endif // CHS_CONCURRENT_TEST_SV
