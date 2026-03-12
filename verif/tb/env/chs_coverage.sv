`ifndef CHS_COVERAGE_SV
`define CHS_COVERAGE_SV

// ============================================================================
// chs_coverage.sv -- Cheshire SoC Functional Coverage Collector
//
// Asama 5: Deep functional coverage with:
//   - JTAG operation & DMI/SBA path coverage
//   - UART data pattern & error coverage
//   - SPI transfer mode, CS selection, transfer size coverage
//   - I2C address, operation, ACK/NACK coverage
//   - GPIO bit pattern, transition, output-enable coverage
//   - Cross-protocol activity coverage (which protocols were exercised)
//   - Boot mode coverage
// ============================================================================

`uvm_analysis_imp_decl(_cov_jtag)
`uvm_analysis_imp_decl(_cov_uart)
`uvm_analysis_imp_decl(_cov_spi)
`uvm_analysis_imp_decl(_cov_i2c)
`uvm_analysis_imp_decl(_cov_gpio)
`uvm_analysis_imp_decl(_cov_axi)

class chs_coverage extends uvm_component;

    // ---------- Analysis imports ----------
    uvm_analysis_imp_cov_jtag #(jtag_transaction, chs_coverage) jtag_imp;
    uvm_analysis_imp_cov_uart #(uart_transaction, chs_coverage) uart_imp;
    uvm_analysis_imp_cov_spi  #(spi_transaction,  chs_coverage) spi_imp;
    uvm_analysis_imp_cov_i2c  #(i2c_transaction,  chs_coverage) i2c_imp;
    uvm_analysis_imp_cov_gpio #(gpio_transaction, chs_coverage) gpio_imp;
    uvm_analysis_imp_cov_axi  #(chs_axi_seq_item, chs_coverage) axi_imp;

    // ---------- Sampled fields ----------
    logic [1:0]  sampled_boot_mode;

    // JTAG
    bit [1:0]    sampled_jtag_op;
    int unsigned sampled_jtag_dr_len;
    bit [4:0]    sampled_jtag_ir;
    bit [4:0]    current_jtag_ir;   // Persistent IR tracking across transactions
    bit [63:0]   sampled_jtag_dr;

    // UART
    bit [7:0]    sampled_uart_data;
    bit          sampled_uart_parity_err;
    bit          sampled_uart_frame_err;
    bit          sampled_uart_dir;

    // SPI
    bit [1:0]    sampled_spi_mode;
    bit [1:0]    sampled_spi_csb;
    int unsigned sampled_spi_mosi_len;
    int unsigned sampled_spi_miso_len;

    // I2C
    bit          sampled_i2c_op;
    bit [6:0]    sampled_i2c_addr;
    int unsigned sampled_i2c_data_len;
    bit          sampled_i2c_ack;

    // GPIO
    bit [31:0]   sampled_gpio_en;
    bit [31:0]   sampled_gpio_data;
    bit [31:0]   sampled_gpio_data_prev;
    bit [1:0]    sampled_gpio_op;

    // Cross-protocol tracking
    bit          jtag_seen;
    bit          uart_seen;
    bit          spi_seen;
    bit          i2c_seen;
    bit          gpio_seen;
    bit          axi_seen;

    // AXI sampled fields
    bit          sampled_axi_rw;         // 0=READ, 1=WRITE
    bit [1:0]    sampled_axi_burst;
    bit [2:0]    sampled_axi_size;
    bit [7:0]    sampled_axi_len;
    bit [1:0]    sampled_axi_resp;
    bit          sampled_axi_lock;
    bit [5:0]    sampled_axi_atop;
    int unsigned sampled_axi_latency;

    // AXI region enum for coverpoint (strings not allowed in coverpoints)
    typedef enum int {
        AXI_REGION_DEBUG       = 0,
        AXI_REGION_BOOTROM     = 1,
        AXI_REGION_CLINT       = 2,
        AXI_REGION_PLIC        = 3,
        AXI_REGION_PERIPHERALS = 4,
        AXI_REGION_LLC_SPM     = 5,
        AXI_REGION_DRAM        = 6,
        AXI_REGION_UNMAPPED    = 7
    } axi_region_e;
    axi_region_e sampled_axi_region;

    // ---------- Environment config handle ----------
    chs_env_config m_env_cfg;

    `uvm_component_utils(chs_coverage)

    // ====================== Covergroups ======================

    // --- Boot Mode Coverage ---
    covergroup cg_boot_mode;
        option.per_instance = 1;
        option.name = "cg_boot_mode";
        cp_boot_mode: coverpoint sampled_boot_mode {
            bins jtag        = {2'b00};
            bins serial_link = {2'b01};
            bins uart        = {2'b10};
            bins reserved    = {2'b11};
        }
    endgroup

    // --- JTAG Coverage (Deep) ---
    covergroup cg_jtag;
        option.per_instance = 1;
        option.name = "cg_jtag";

        cp_jtag_op: coverpoint sampled_jtag_op {
            bins reset   = {2'b00};
            bins ir_scan = {2'b01};
            bins dr_scan = {2'b10};
            bins idle    = {2'b11};
        }

        cp_dr_length: coverpoint sampled_jtag_dr_len {
            bins zero      = {0};
            bins short_dr  = {[1:8]};
            bins medium_dr = {[9:32]};
            bins long_dr   = {[33:41]};
            bins very_long = {[42:64]};
        }

        cp_ir_value: coverpoint sampled_jtag_ir {
            bins idcode    = {5'h01};
            bins dtmcs     = {5'h10};
            bins dmi       = {5'h11};
            bins bypass    = {5'h1f};
            bins others    = default;
        }

        // Cross: operation type x IR value
        cx_op_ir: cross cp_jtag_op, cp_ir_value {
            bins ir_to_idcode = binsof(cp_jtag_op.ir_scan) && binsof(cp_ir_value.idcode);
            bins ir_to_dmi    = binsof(cp_jtag_op.ir_scan) && binsof(cp_ir_value.dmi);
            bins ir_to_dtmcs  = binsof(cp_jtag_op.ir_scan) && binsof(cp_ir_value.dtmcs);
            bins dr_with_idcode = binsof(cp_jtag_op.dr_scan) && binsof(cp_ir_value.idcode);
            bins dr_with_dmi    = binsof(cp_jtag_op.dr_scan) && binsof(cp_ir_value.dmi);
        }

        // DMI operation tracking
        cp_dmi_op: coverpoint sampled_jtag_dr[1:0] iff (sampled_jtag_ir == 5'h11 && sampled_jtag_op == 2'b10) {
            bins nop    = {2'b00};
            bins read   = {2'b01};
            bins write  = {2'b10};
            bins rsv    = {2'b11};
        }

        // SBA address range tracking
        cp_dmi_addr: coverpoint sampled_jtag_dr[40:34] iff (sampled_jtag_ir == 5'h11 && sampled_jtag_op == 2'b10) {
            bins sbcs       = {7'h38};
            bins sbaddr0    = {7'h39};
            bins sbdata0    = {7'h3C};
            bins dmcontrol  = {7'h10};
            bins dmstatus   = {7'h11};
            bins others     = default;
        }
    endgroup

    // --- UART Coverage (Deep) ---
    covergroup cg_uart;
        option.per_instance = 1;
        option.name = "cg_uart";

        cp_uart_data: coverpoint sampled_uart_data {
            bins zero          = {8'h00};
            bins control_chars = {[8'h01 : 8'h1f]};
            bins printable_low = {[8'h20 : 8'h3f]};
            bins printable_mid = {[8'h40 : 8'h5f]};
            bins printable_hi  = {[8'h60 : 8'h7e]};
            bins del           = {8'h7f};
            bins high_range    = {[8'h80 : 8'hfe]};
            bins all_ones      = {8'hff};
        }

        cp_uart_dir: coverpoint sampled_uart_dir {
            bins tx = {1'b0};
            bins rx = {1'b1};
        }

        cp_parity_error: coverpoint sampled_uart_parity_err {
            bins no_err  = {1'b0};
            bins has_err = {1'b1};
        }

        cp_frame_error: coverpoint sampled_uart_frame_err {
            bins no_err  = {1'b0};
            bins has_err = {1'b1};
        }

        cx_data_dir: cross cp_uart_data, cp_uart_dir;
        cx_errors: cross cp_parity_error, cp_frame_error;
    endgroup

    // --- SPI Coverage (Deep) ---
    covergroup cg_spi;
        option.per_instance = 1;
        option.name = "cg_spi";

        cp_spi_mode: coverpoint sampled_spi_mode {
            bins standard = {2'b00};
            bins dual     = {2'b01};
            bins quad     = {2'b10};
        }

        cp_csb_sel: coverpoint sampled_spi_csb {
            bins cs0 = {2'b00};
            bins cs1 = {2'b01};
        }

        cp_mosi_len: coverpoint sampled_spi_mosi_len {
            bins empty     = {0};
            bins single    = {1};
            bins short_tr  = {[2:4]};
            bins medium_tr = {[5:16]};
            bins long_tr   = {[17:256]};
        }

        cp_miso_len: coverpoint sampled_spi_miso_len {
            bins empty     = {0};
            bins single    = {1};
            bins short_tr  = {[2:4]};
            bins medium_tr = {[5:16]};
            bins long_tr   = {[17:256]};
        }

        cx_mode_cs: cross cp_spi_mode, cp_csb_sel;
        cx_mode_len: cross cp_spi_mode, cp_mosi_len;
    endgroup

    // --- I2C Coverage (Deep) ---
    covergroup cg_i2c;
        option.per_instance = 1;
        option.name = "cg_i2c";

        cp_i2c_op: coverpoint sampled_i2c_op {
            bins write = {1'b0};
            bins read  = {1'b1};
        }

        cp_i2c_addr: coverpoint sampled_i2c_addr {
            bins general_call = {7'h00};
            bins eeprom_range = {[7'h50 : 7'h57]};
            bins sensor_range = {[7'h40 : 7'h4f]};
            bins others       = default;
        }

        cp_i2c_data_len: coverpoint sampled_i2c_data_len {
            bins none     = {0};
            bins single   = {1};
            bins short_d  = {[2:4]};
            bins medium_d = {[5:16]};
            bins long_d   = {[17:64]};
        }

        cp_i2c_ack: coverpoint sampled_i2c_ack {
            bins ack  = {1'b1};
            bins nack = {1'b0};
        }

        cx_op_ack: cross cp_i2c_op, cp_i2c_ack;
        cx_addr_op: cross cp_i2c_addr, cp_i2c_op;
    endgroup

    // --- GPIO Coverage (Deep) ---
    covergroup cg_gpio;
        option.per_instance = 1;
        option.name = "cg_gpio";

        cp_gpio_op: coverpoint sampled_gpio_op {
            bins drive_input = {1'b0};
            bins read_output = {1'b1};
        }

        cp_gpio_en_pattern: coverpoint sampled_gpio_en {
            bins all_input    = {32'h0000_0000};
            bins all_output   = {32'hFFFF_FFFF};
            bins lower_half   = {32'h0000_FFFF};
            bins upper_half   = {32'hFFFF_0000};
            bins lower_byte   = {32'h0000_00FF};
            bins byte_pattern = {32'h00FF_00FF};
            bins mixed        = default;
        }

        cp_gpio_data_pattern: coverpoint sampled_gpio_data {
            bins all_zero     = {32'h0000_0000};
            bins all_one      = {32'hFFFF_FFFF};
            bins checkerboard = {32'h5555_5555, 32'hAAAA_AAAA};
            bins walking_one  = {32'h0000_0001, 32'h0000_0002, 32'h0000_0004,
                                 32'h0000_0008, 32'h0000_0010, 32'h0000_0020,
                                 32'h0000_0040, 32'h0000_0080};
            bins others       = default;
        }

        cp_gpio_transition: coverpoint (sampled_gpio_data ^ sampled_gpio_data_prev) {
            bins no_change     = {32'h0000_0000};
            bins single_bit    = {32'h0000_0001, 32'h0000_0002, 32'h0000_0004,
                                  32'h0000_0008, 32'h0000_0010, 32'h0000_0020,
                                  32'h0000_0040, 32'h0000_0080};
            bins multi_bit     = default;
        }

        cx_en_data: cross cp_gpio_en_pattern, cp_gpio_data_pattern;
    endgroup

    // --- Cross-Protocol Activity Coverage ---
    covergroup cg_cross_protocol;
        option.per_instance = 1;
        option.name = "cg_cross_protocol";

        cp_jtag_active: coverpoint jtag_seen {
            bins inactive = {1'b0};
            bins active   = {1'b1};
        }
        cp_uart_active: coverpoint uart_seen {
            bins inactive = {1'b0};
            bins active   = {1'b1};
        }
        cp_spi_active: coverpoint spi_seen {
            bins inactive = {1'b0};
            bins active   = {1'b1};
        }
        cp_i2c_active: coverpoint i2c_seen {
            bins inactive = {1'b0};
            bins active   = {1'b1};
        }
        cp_gpio_active: coverpoint gpio_seen {
            bins inactive = {1'b0};
            bins active   = {1'b1};
        }

        cx_all_protocols: cross cp_jtag_active, cp_uart_active,
                                cp_spi_active, cp_i2c_active, cp_gpio_active {
            bins jtag_only       = binsof(cp_jtag_active.active) &&
                                   binsof(cp_uart_active.inactive) &&
                                   binsof(cp_spi_active.inactive) &&
                                   binsof(cp_i2c_active.inactive) &&
                                   binsof(cp_gpio_active.inactive);
            bins jtag_uart_gpio  = binsof(cp_jtag_active.active) &&
                                   binsof(cp_uart_active.active) &&
                                   binsof(cp_gpio_active.active);
            bins jtag_spi        = binsof(cp_jtag_active.active) &&
                                   binsof(cp_spi_active.active);
            bins all_active      = binsof(cp_jtag_active.active) &&
                                   binsof(cp_uart_active.active) &&
                                   binsof(cp_spi_active.active) &&
                                   binsof(cp_i2c_active.active) &&
                                   binsof(cp_gpio_active.active);
        }
    endgroup

    // --- AXI Bus Coverage (Deep) ---
    covergroup cg_axi;
        option.per_instance = 1;
        option.name = "cg_axi";

        cp_axi_rw: coverpoint sampled_axi_rw {
            bins read  = {1'b0};
            bins write = {1'b1};
        }

        cp_axi_burst: coverpoint sampled_axi_burst {
            bins fixed = {2'b00};
            bins incr  = {2'b01};
            bins wrap  = {2'b10};
        }

        cp_axi_size: coverpoint sampled_axi_size {
            bins byte_1  = {3'b000};
            bins byte_2  = {3'b001};
            bins byte_4  = {3'b010};
            bins byte_8  = {3'b011};
        }

        cp_axi_len: coverpoint sampled_axi_len {
            bins single     = {0};
            bins short_2_4  = {[1:3]};
            bins medium_5_8 = {[4:7]};
            bins long_9_16  = {[8:15]};
            bins very_long  = {[16:255]};
        }

        cp_axi_resp: coverpoint sampled_axi_resp {
            bins okay   = {2'b00};
            bins exokay = {2'b01};
            bins slverr = {2'b10};
            bins decerr = {2'b11};
        }

        cp_axi_lock: coverpoint sampled_axi_lock {
            bins normal    = {1'b0};
            bins exclusive = {1'b1};
        }

        cp_axi_atop: coverpoint sampled_axi_atop {
            bins none = {6'b0};
            bins atop_active = {[1:63]};
        }

        cp_axi_latency: coverpoint sampled_axi_latency {
            bins fast    = {[0:5]};
            bins normal  = {[6:20]};
            bins slow    = {[21:100]};
            bins very_slow = {[101:$]};
        }

        // Cross coverage
        cx_rw_burst:   cross cp_axi_rw, cp_axi_burst;
        cx_rw_size:    cross cp_axi_rw, cp_axi_size;
        cx_rw_len:     cross cp_axi_rw, cp_axi_len;
        cx_rw_resp:    cross cp_axi_rw, cp_axi_resp;
        cx_rw_latency: cross cp_axi_rw, cp_axi_latency;
        cx_burst_len:  cross cp_axi_burst, cp_axi_len;
    endgroup

    // --- AXI Address Region Coverage ---
    covergroup cg_axi_region;
        option.per_instance = 1;
        option.name = "cg_axi_region";

        cp_region: coverpoint sampled_axi_region {
            bins debug       = {AXI_REGION_DEBUG};
            bins bootrom     = {AXI_REGION_BOOTROM};
            bins clint       = {AXI_REGION_CLINT};
            bins plic        = {AXI_REGION_PLIC};
            bins peripherals = {AXI_REGION_PERIPHERALS};
            bins llc_spm     = {AXI_REGION_LLC_SPM};
            bins dram        = {AXI_REGION_DRAM};
            bins unmapped    = {AXI_REGION_UNMAPPED};
        }

        cp_region_rw: coverpoint sampled_axi_rw {
            bins read  = {1'b0};
            bins write = {1'b1};
        }

        cx_region_rw: cross cp_region, cp_region_rw;
    endgroup

    // ====================== Constructor ======================
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_boot_mode      = new();
        cg_uart            = new();
        cg_jtag            = new();
        cg_spi             = new();
        cg_i2c             = new();
        cg_gpio            = new();
        cg_cross_protocol  = new();
        cg_axi             = new();
        cg_axi_region      = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        jtag_imp = new("jtag_imp", this);
        uart_imp = new("uart_imp", this);
        spi_imp  = new("spi_imp",  this);
        i2c_imp  = new("i2c_imp",  this);
        gpio_imp = new("gpio_imp", this);
        axi_imp  = new("axi_imp",  this);

        if (!uvm_config_db#(chs_env_config)::get(this, "", "m_env_cfg", m_env_cfg))
            `uvm_warning("NOCFG", "Environment config not found in coverage collector")

        sampled_gpio_data_prev = '0;
        current_jtag_ir = '0;

        jtag_seen = 0;
        uart_seen = 0;
        spi_seen  = 0;
        i2c_seen  = 0;
        gpio_seen = 0;
        axi_seen  = 0;
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        if (m_env_cfg != null) begin
            sampled_boot_mode = m_env_cfg.boot_mode;
            cg_boot_mode.sample();
        end
    endfunction

    // ====================== Write Functions ======================

    function void write_cov_jtag(jtag_transaction tr);
        sampled_jtag_op     = tr.op;
        sampled_jtag_dr_len = tr.dr_length;
        // Track current IR persistently: only update on IR_SCAN, keep for DR_SCAN
        if (tr.op == 2'b01)  // IR_SCAN
            current_jtag_ir = tr.ir_value;
        sampled_jtag_ir     = current_jtag_ir;  // Always use persistent IR
        sampled_jtag_dr     = tr.dr_value;
        jtag_seen = 1;
        cg_jtag.sample();
    endfunction

    function void write_cov_uart(uart_transaction tr);
        sampled_uart_data       = tr.data;
        sampled_uart_parity_err = tr.parity_error;
        sampled_uart_frame_err  = tr.frame_error;
        sampled_uart_dir        = tr.direction;
        uart_seen = 1;
        cg_uart.sample();
    endfunction

    function void write_cov_spi(spi_transaction tr);
        sampled_spi_mode     = tr.mode;
        sampled_spi_csb      = tr.csb_sel;
        sampled_spi_mosi_len = tr.mosi_data.size();
        sampled_spi_miso_len = tr.miso_data.size();
        spi_seen = 1;
        cg_spi.sample();
    endfunction

    function void write_cov_i2c(i2c_transaction tr);
        sampled_i2c_op       = tr.op;
        sampled_i2c_addr     = tr.slave_addr;
        sampled_i2c_data_len = tr.data.size();
        sampled_i2c_ack      = tr.ack_received;
        i2c_seen = 1;
        cg_i2c.sample();
    endfunction

    function void write_cov_gpio(gpio_transaction tr);
        sampled_gpio_data_prev = sampled_gpio_data;
        sampled_gpio_en        = tr.observed_en;
        sampled_gpio_data      = tr.observed_output;
        sampled_gpio_op        = tr.op;
        gpio_seen = 1;
        cg_gpio.sample();
    endfunction

    function void write_cov_axi(chs_axi_seq_item tr);
        string region_str;
        sampled_axi_rw      = tr.rw;
        sampled_axi_burst   = tr.burst;
        sampled_axi_size    = tr.size;
        sampled_axi_len     = tr.len;
        sampled_axi_resp    = tr.resp;
        sampled_axi_lock    = tr.lock;
        sampled_axi_atop    = tr.atop;
        sampled_axi_latency = tr.latency_cycles;
        region_str          = tr.get_region();
        case (region_str)
            "DEBUG":       sampled_axi_region = AXI_REGION_DEBUG;
            "BOOTROM":     sampled_axi_region = AXI_REGION_BOOTROM;
            "CLINT":       sampled_axi_region = AXI_REGION_CLINT;
            "PLIC":        sampled_axi_region = AXI_REGION_PLIC;
            "PERIPHERALS": sampled_axi_region = AXI_REGION_PERIPHERALS;
            "LLC_SPM":     sampled_axi_region = AXI_REGION_LLC_SPM;
            "DRAM":        sampled_axi_region = AXI_REGION_DRAM;
            default:       sampled_axi_region = AXI_REGION_UNMAPPED;
        endcase
        axi_seen = 1;
        cg_axi.sample();
        cg_axi_region.sample();
    endfunction

    // ====================== Report Phase ======================
    function void report_phase(uvm_phase phase);
        real jtag_cov, uart_cov, spi_cov, i2c_cov, gpio_cov, boot_cov, cross_cov;
        real axi_cov, axi_region_cov;
        real total_cov;

        super.report_phase(phase);

        // Sample cross-protocol coverage at end of test
        cg_cross_protocol.sample();

        jtag_cov       = cg_jtag.get_coverage();
        uart_cov       = cg_uart.get_coverage();
        spi_cov        = cg_spi.get_coverage();
        i2c_cov        = cg_i2c.get_coverage();
        gpio_cov       = cg_gpio.get_coverage();
        boot_cov       = cg_boot_mode.get_coverage();
        cross_cov      = cg_cross_protocol.get_coverage();
        axi_cov        = cg_axi.get_coverage();
        axi_region_cov = cg_axi_region.get_coverage();
        total_cov = (jtag_cov + uart_cov + spi_cov + i2c_cov + gpio_cov +
                     boot_cov + cross_cov + axi_cov + axi_region_cov) / 9.0;

        `uvm_info("COV_REPORT", $sformatf({"\n",
            "============================================================\n",
            "  Functional Coverage Report\n",
            "============================================================\n",
            "  Boot Mode      : %5.1f%%\n",
            "  JTAG Protocol  : %5.1f%%\n",
            "  UART Protocol  : %5.1f%%\n",
            "  SPI  Protocol  : %5.1f%%\n",
            "  I2C  Protocol  : %5.1f%%\n",
            "  GPIO Protocol  : %5.1f%%\n",
            "  AXI  Bus       : %5.1f%%\n",
            "  AXI  Regions   : %5.1f%%\n",
            "  Cross-Protocol : %5.1f%%\n",
            "------------------------------------------------------------\n",
            "  Average        : %5.1f%%\n",
            "============================================================"},
            boot_cov, jtag_cov, uart_cov, spi_cov,
            i2c_cov, gpio_cov, axi_cov, axi_region_cov,
            cross_cov, total_cov), UVM_LOW)
    endfunction

endclass : chs_coverage

`endif // CHS_COVERAGE_SV
