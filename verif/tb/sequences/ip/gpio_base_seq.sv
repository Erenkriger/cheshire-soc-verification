`ifndef GPIO_BASE_SEQ_SV
`define GPIO_BASE_SEQ_SV

// ============================================================================
// gpio_base_seq.sv — Base GPIO Sequence
// Provides reusable helper tasks:
//   - drive_pins, drive_all
// ============================================================================

class gpio_base_seq extends uvm_sequence #(gpio_transaction);

    `uvm_object_utils(gpio_base_seq)

    function new(string name = "gpio_base_seq");
        super.new(name);
    endfunction

    // ========================== Helper Tasks ==========================

    // ---- Drive Specific Pins ----
    virtual task drive_pins(bit [31:0] data, bit [31:0] mask,
                            uvm_sequencer_base sqr = null);
        gpio_transaction txn;
        txn = gpio_transaction::type_id::create("txn_drive");
        start_item(txn, -1, sqr);
        txn.op   = gpio_transaction::DRIVE_INPUT;
        txn.data = data;
        txn.mask = mask;
        finish_item(txn);
        `uvm_info(get_type_name(),
                  $sformatf("GPIO drive_pins: data=0x%08h mask=0x%08h", data, mask),
                  UVM_HIGH)
    endtask : drive_pins

    // ---- Drive All Pins ----
    virtual task drive_all(bit [31:0] data, uvm_sequencer_base sqr = null);
        drive_pins(data, 32'hFFFF_FFFF, sqr);
        `uvm_info(get_type_name(),
                  $sformatf("GPIO drive_all: data=0x%08h", data), UVM_MEDIUM)
    endtask : drive_all

    // ========================== Default body ==========================
    virtual task body();
        `uvm_info(get_type_name(), "gpio_base_seq — default body (no-op)", UVM_LOW)
    endtask : body

endclass : gpio_base_seq

`endif // GPIO_BASE_SEQ_SV
