`ifndef GPIO_MONITOR_SV
`define GPIO_MONITOR_SV

// ============================================================================
// gpio_monitor.sv — GPIO Monitor
// Monitors gpio_o and gpio_en_o (DUT output), reports changes
// ============================================================================

class gpio_monitor extends uvm_monitor;

    virtual gpio_if vif;
    gpio_config     m_cfg;

    uvm_analysis_port #(gpio_transaction) ap;

    // Previous values for edge detection
    bit [31:0] prev_gpio_o;
    bit [31:0] prev_gpio_en;

    `uvm_component_utils(gpio_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual gpio_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "GPIO virtual interface not found")
        if (!uvm_config_db#(gpio_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "GPIO config not found")
    endfunction

    task run_phase(uvm_phase phase);
        // Initialize previous values
        prev_gpio_o  = '0;
        prev_gpio_en = '0;

        // Wait for reset de-assertion
        @(posedge vif.rst_n);

        monitor_outputs();
    endtask

    // Monitor DUT gpio_o and gpio_en_o for changes
    task monitor_outputs();
        gpio_transaction tr;
        bit [31:0] curr_gpio_o;
        bit [31:0] curr_gpio_en;

        forever begin
            @(posedge vif.clk);

            curr_gpio_o  = vif.gpio_o;
            curr_gpio_en = vif.gpio_en_o;

            // Detect any change on output or output-enable
            if (curr_gpio_o !== prev_gpio_o || curr_gpio_en !== prev_gpio_en) begin
                tr = gpio_transaction::type_id::create("gpio_mon_tr");
                tr.op              = gpio_transaction::READ_OUTPUT;
                tr.data            = curr_gpio_o;
                tr.mask            = curr_gpio_o ^ prev_gpio_o;  // Changed bits
                tr.observed_output = curr_gpio_o;
                tr.observed_en     = curr_gpio_en;

                `uvm_info("GPIO_MON", $sformatf(
                    "Output change: gpio_o=0x%08h gpio_en=0x%08h (delta_o=0x%08h delta_en=0x%08h)",
                    curr_gpio_o, curr_gpio_en,
                    curr_gpio_o ^ prev_gpio_o, curr_gpio_en ^ prev_gpio_en), UVM_HIGH)

                ap.write(tr);

                prev_gpio_o  = curr_gpio_o;
                prev_gpio_en = curr_gpio_en;
            end
        end
    endtask

endclass : gpio_monitor

`endif // GPIO_MONITOR_SV
