`ifndef CHS_JTAG_SBA_TEST_SV
`define CHS_JTAG_SBA_TEST_SV

// ============================================================================
// chs_jtag_sba_test.sv — JTAG SBA System Bus Access Test
//
// Exercises the full SoC-level verification path:
//   JTAG → DMI → Debug Module → SBA → AXI → Regbus → Peripheral CSR
//
// This is the first test that actually programs DUT peripheral registers,
// causing DUT hardware to generate output signals that monitors can capture.
//
// Timeout: 50ms (SBA operations are slow — each requires multiple DMI
// transactions through the JTAG TAP FSM at 50MHz TCK)
// ============================================================================

class chs_jtag_sba_test extends chs_base_test;

    `uvm_component_utils(chs_jtag_sba_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        // Increase timeout: SBA chain goes through JTAG → DMI → AXI → Regbus
        // Each SBA write requires ~4 DMI operations, each DMI requires
        // IR+DR scans at TCK rate. UART TX frames need 87µs each at 115200.
        m_timeout = 100ms;
    endfunction

    virtual task test_body();
        chs_jtag_sba_vseq vseq;

        `uvm_info(get_type_name(),
                  "========== JTAG SBA System Bus Access Test ==========", UVM_LOW)
        `uvm_info(get_type_name(),
                  "Testing: JTAG -> DMI -> Debug Module -> SBA -> AXI -> Peripheral", UVM_LOW)

        vseq = chs_jtag_sba_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
                  "========== JTAG SBA Test Complete ==========", UVM_LOW)
    endtask : test_body

endclass : chs_jtag_sba_test

`endif
