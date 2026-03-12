`ifndef GPIO_DRIVER_SV
`define GPIO_DRIVER_SV

// ============================================================================
// gpio_driver.sv — GPIO Driver
// Drives the gpio_i pins (TB → DUT input stimulus)
// ============================================================================

class gpio_driver extends uvm_driver #(gpio_transaction);

    virtual gpio_if vif;
    gpio_config     m_cfg;

    `uvm_component_utils(gpio_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual gpio_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "GPIO virtual interface not found")
        if (!uvm_config_db#(gpio_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "GPIO config not found")
    endfunction

    task run_phase(uvm_phase phase);
        gpio_transaction tr;

        // Default: all gpio inputs low
        vif.gpio_i <= '0;

        forever begin
            seq_item_port.get_next_item(tr);
            drive_pins(tr);
            seq_item_port.item_done();
        end
    endtask

    // Drive gpio_i pins based on transaction data and mask
    task drive_pins(gpio_transaction tr);
        bit [31:0] current_val;
        bit [31:0] new_val;

        if (tr.op == gpio_transaction::DRIVE_INPUT) begin
            current_val = vif.gpio_i;
            // Apply masked write: only bits with mask=1 are updated
            new_val = (current_val & ~tr.mask) | (tr.data & tr.mask);
            @(posedge vif.clk);
            vif.gpio_i <= new_val;
            `uvm_info("GPIO_DRV", $sformatf("Driving gpio_i = 0x%08h (mask=0x%08h)",
                new_val, tr.mask), UVM_HIGH)
        end
    endtask

endclass : gpio_driver

`endif // GPIO_DRIVER_SV
