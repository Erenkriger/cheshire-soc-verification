// ============================================================================
// usb_sequencer.sv — USB Sequencer
// ============================================================================

`ifndef USB_SEQUENCER_SV
`define USB_SEQUENCER_SV

class usb_sequencer extends uvm_sequencer #(usb_transaction);

    `uvm_component_utils(usb_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass : usb_sequencer

`endif // USB_SEQUENCER_SV
