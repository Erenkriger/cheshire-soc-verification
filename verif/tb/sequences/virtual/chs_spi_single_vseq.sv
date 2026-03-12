`ifndef CHS_SPI_SINGLE_VSEQ_SV
`define CHS_SPI_SINGLE_VSEQ_SV

// ============================================================================
// chs_spi_single_vseq.sv — SPI Single Transfer Virtual Sequence
// Sends a few individual SPI bytes to verify basic SPI slave response.
// ============================================================================

class chs_spi_single_vseq extends uvm_sequence;

    `uvm_object_utils(chs_spi_single_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_spi_single_vseq");
        super.new(name);
    endfunction

    virtual task body();
        spi_base_seq spi_seq;

        `uvm_info(get_type_name(),
                  "===== SPI Single Transfer START =====", UVM_LOW)

        spi_seq = spi_base_seq::type_id::create("spi_seq");

        // Send individual bytes
        `uvm_info(get_type_name(), "Sending SPI bytes: 0x9F, 0xAB, 0x55", UVM_MEDIUM)
        spi_seq.send_byte(8'h9F, p_sequencer.m_spi_sqr);  // JEDEC ID cmd
        spi_seq.send_byte(8'hAB, p_sequencer.m_spi_sqr);  // Release power-down
        spi_seq.send_byte(8'h55, p_sequencer.m_spi_sqr);  // Pattern byte

        // Read back dummy data
        `uvm_info(get_type_name(), "Reading 4 dummy bytes", UVM_MEDIUM)
        spi_seq.read_bytes(4, p_sequencer.m_spi_sqr);

        `uvm_info(get_type_name(),
                  "===== SPI Single Transfer COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_spi_single_vseq

`endif
