`ifndef CHS_BASE_TEST_SV
`define CHS_BASE_TEST_SV

// ============================================================================
// chs_base_test.sv — Cheshire SoC Base Test
// Creates the environment, configures agents, provides objection
// framework with configurable timeout, and defines test_body()
// as a hook for subclass override.
// ============================================================================

class chs_base_test extends uvm_test;

    `uvm_component_utils(chs_base_test)

    // ---------- Environment ----------
    chs_env        m_env;
    chs_env_config m_env_cfg;

    // ---------- Timeout ----------
    time m_timeout = 10ms;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ========================== Build Phase ==========================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // ---- Create environment configuration ----
        m_env_cfg = chs_env_config::type_id::create("m_env_cfg");

        // ---- Create agent configs with defaults ----
        m_env_cfg.m_jtag_cfg = jtag_config::type_id::create("m_jtag_cfg");
        m_env_cfg.m_uart_cfg = uart_config::type_id::create("m_uart_cfg");
        m_env_cfg.m_spi_cfg  = spi_config::type_id::create("m_spi_cfg");
        m_env_cfg.m_i2c_cfg  = i2c_config::type_id::create("m_i2c_cfg");
        m_env_cfg.m_gpio_cfg = gpio_config::type_id::create("m_gpio_cfg");

        // ---- Allow subclass to customize ----
        configure_env();

        // ---- Push env config into config_db ----
        uvm_config_db#(chs_env_config)::set(this, "m_env*", "m_env_cfg", m_env_cfg);

        // ---- Create environment ----
        m_env = chs_env::type_id::create("m_env", this);
    endfunction : build_phase

    // ========================== End of Elaboration ==========================
    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction : end_of_elaboration_phase

    // ========================== Run Phase ==========================
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        phase.raise_objection(this, {get_type_name(), " — starting test"});

        // Fork: test_body vs. timeout watchdog
        fork : watchdog_fork
            begin
                wait_for_reset();
                test_body();
            end
            begin
                #(m_timeout);
                `uvm_fatal(get_type_name(),
                           $sformatf("Test timeout after %0t", m_timeout))
            end
        join_any
        disable watchdog_fork;

        phase.drop_objection(this, {get_type_name(), " — test done"});
    endtask : run_phase

    // ========================== Virtual Hooks ==========================

    // Override in subclass to customize env config before build
    virtual function void configure_env();
    endfunction : configure_env

    // Override in subclass with actual test stimulus
    virtual task test_body();
        `uvm_info(get_type_name(),
                  "chs_base_test::test_body — override in subclass", UVM_LOW)
    endtask : test_body

    // ========================== Utility ==========================

    // Wait for DUT reset de-assertion (simple clock-based wait)
    virtual task wait_for_reset();
        `uvm_info(get_type_name(), "Waiting for reset de-assertion ...", UVM_MEDIUM)
        #100ns;
        `uvm_info(get_type_name(), "Reset phase complete", UVM_MEDIUM)
    endtask : wait_for_reset

endclass : chs_base_test

`endif // CHS_BASE_TEST_SV
