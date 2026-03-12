// ============================================================================
// chs_periph_stress_test.sv — Multi-Peripheral Stress Test
//
// Aşama 7: Aggressive stress of SBA→AXI→RegBus path with rapid
// alternating accesses to all 4 peripherals + DRAM.
// ============================================================================

`ifndef CHS_PERIPH_STRESS_TEST_SV
`define CHS_PERIPH_STRESS_TEST_SV

class chs_periph_stress_test extends chs_base_test;

    `uvm_component_utils(chs_periph_stress_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 100ms;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "========== Peripheral Stress Test ==========", UVM_LOW)
    endfunction

    virtual task test_body();
        chs_periph_stress_vseq vseq;
        vseq = chs_periph_stress_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);
        `uvm_info(get_type_name(), "========== Peripheral Stress Test Complete ==========", UVM_LOW)
    endtask

endclass

`endif // CHS_PERIPH_STRESS_TEST_SV
