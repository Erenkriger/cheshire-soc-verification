// ============================================================================
// chs_sva_coverage_test.sv -- SVA + Coverage Verification Test
//
// Asama 5: Runs the coverage-driven sequence that exercises all protocols
// to maximize functional coverage and trigger SVA assertions.
//
// This test:
//   - Enables all 5 agents (JTAG, UART, SPI, I2C, GPIO)
//   - Runs chs_coverage_drive_vseq to hit coverage targets
//   - SVA assertions in chs_protocol_checker are active throughout
//   - Coverage results printed in report_phase
// ============================================================================

`ifndef CHS_SVA_COVERAGE_TEST_SV
`define CHS_SVA_COVERAGE_TEST_SV

class chs_sva_coverage_test extends chs_base_test;

    `uvm_component_utils(chs_sva_coverage_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 200ms timeout (coverage test exercises all protocols sequentially)
        m_timeout = 200_000_000;
    endfunction

    task run_phase(uvm_phase phase);
        chs_coverage_drive_vseq vseq;
        phase.raise_objection(this);

        `uvm_info(get_type_name(),
            "========== SVA + Coverage Test ==========", UVM_LOW)
        `uvm_info(get_type_name(),
            "Testing: All 5 protocols for coverage + SVA compliance", UVM_LOW)

        vseq = chs_coverage_drive_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
            "========== SVA + Coverage Test Complete ==========", UVM_LOW)

        phase.drop_objection(this);
    endtask

endclass : chs_sva_coverage_test

`endif // CHS_SVA_COVERAGE_TEST_SV
