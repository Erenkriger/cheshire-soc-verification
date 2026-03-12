`ifndef SPI_DRIVER_SV
`define SPI_DRIVER_SV

// ============================================================================
// spi_driver.sv — SPI Slave Driver
// Since the DUT is the SPI master, this driver acts as a slave device.
// It drives sd_i (MISO) lines in response to master SCK activity.
// ============================================================================

class spi_driver extends uvm_driver #(spi_transaction);

    virtual spi_if vif;
    spi_config     m_cfg;

    `uvm_component_utils(spi_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "SPI virtual interface not found in config_db")
        if (!uvm_config_db#(spi_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "SPI config not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        spi_transaction tr;

        // Initialize sd_i lines to high-impedance / default high
        vif.sd_i <= 4'hF;

        forever begin
            seq_item_port.get_next_item(tr);
            drive_slave_response(tr);
            seq_item_port.item_done();
        end
    endtask

    // Drive slave response data on sd_i lines
    // Includes timeout guard: if DUT SPI master never asserts CS,
    // the transaction completes with a warning instead of hanging.
    task drive_slave_response(spi_transaction tr);
        bit timed_out = 0;

        if (m_cfg.driver_timeout > 0) begin
            fork
                begin : spi_actual_drive
                    do_slave_response(tr);
                end
                begin : spi_timeout_guard
                    #(m_cfg.driver_timeout);
                    timed_out = 1;
                end
            join_any
            disable spi_actual_drive;
            disable spi_timeout_guard;

            if (timed_out) begin
                `uvm_warning("SPI_DRV", $sformatf(
                    "Slave response timeout (%0t) - DUT SPI master did not assert CS. Ensure SPI controller is programmed via CSR before running SPI slave tests.",
                    m_cfg.driver_timeout))
            end
        end else begin
            do_slave_response(tr);
        end
    endtask : drive_slave_response

    // Actual slave response logic (extracted for timeout wrapping)
    task do_slave_response(spi_transaction tr);
        int unsigned bits_per_cycle;
        int unsigned total_bits;
        int unsigned bit_idx;
        bit [7:0] current_byte;

        // Determine bits per SCK cycle based on mode
        case (tr.mode)
            spi_transaction::SPI_STANDARD: bits_per_cycle = 1;
            spi_transaction::SPI_DUAL:     bits_per_cycle = 2;
            spi_transaction::SPI_QUAD:     bits_per_cycle = 4;
            default:                       bits_per_cycle = 1;
        endcase

        `uvm_info("SPI_DRV", $sformatf("Driving slave response: %0d bytes, mode=%s",
            tr.data.size(), tr.mode.name()), UVM_HIGH)

        // Wait for CS assertion (active low) on selected chip select
        wait (vif.csb[tr.csb_sel] === 1'b0);

        // Drive response data byte-by-byte on sd_i
        for (int byte_idx = 0; byte_idx < tr.data.size(); byte_idx++) begin
            current_byte = tr.data[byte_idx];
            bit_idx = 8;

            while (bit_idx > 0) begin
                // Wait for appropriate SCK edge based on CPOL/CPHA
                if (m_cfg.cpol == m_cfg.cpha)
                    @(negedge vif.sck);   // Drive on falling edge (sample on rising)
                else
                    @(posedge vif.sck);   // Drive on rising edge (sample on falling)

                // Check if CS still asserted
                if (vif.csb[tr.csb_sel] !== 1'b0) begin
                    `uvm_info("SPI_DRV", "CS de-asserted during transfer", UVM_MEDIUM)
                    vif.sd_i <= 4'hF;
                    return;
                end

                // Drive bits MSB first on sd_i
                case (tr.mode)
                    spi_transaction::SPI_STANDARD: begin
                        bit_idx--;
                        vif.sd_i[1] <= current_byte[bit_idx];  // MISO = sd_i[1]
                        vif.sd_i[0] <= 1'b0;
                        vif.sd_i[3:2] <= 2'b00;
                    end
                    spi_transaction::SPI_DUAL: begin
                        bit_idx -= 2;
                        vif.sd_i[1:0] <= current_byte[bit_idx +: 2];
                        vif.sd_i[3:2] <= 2'b00;
                    end
                    spi_transaction::SPI_QUAD: begin
                        bit_idx -= 4;
                        vif.sd_i[3:0] <= current_byte[bit_idx +: 4];
                    end
                endcase
            end
        end

        // Wait for CS de-assertion
        wait (vif.csb[tr.csb_sel] === 1'b1);
        vif.sd_i <= 4'hF;

        `uvm_info("SPI_DRV", "Slave response complete", UVM_HIGH)
    endtask : do_slave_response

endclass : spi_driver

`endif // SPI_DRIVER_SV
