// ============================================================================
// chs_ral_spi_regs.sv — SPI Host Register Block (RAL)
//
// Base: 0x0300_4000 (OpenTitan SPI Host)
// Registers: CONTROL, STATUS, CONFIGOPTS, CSID, COMMAND, TXDATA, RXDATA,
//            ERR_ENABLE, ERR_STATUS, EVENT_ENABLE
// ============================================================================

`ifndef CHS_RAL_SPI_REGS_SV
`define CHS_RAL_SPI_REGS_SV

// ─── CONTROL register (0x10) ───
class chs_ral_spi_control extends uvm_reg;
    `uvm_object_utils(chs_ral_spi_control)

    rand uvm_reg_field tx_watermark;
    rand uvm_reg_field rx_watermark;
    rand uvm_reg_field spien;
    rand uvm_reg_field output_en;

    function new(string name = "chs_ral_spi_control");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        tx_watermark = uvm_reg_field::type_id::create("tx_watermark");
        tx_watermark.configure(this, 8, 0, "RW", 0, 8'h0, 1, 1, 0);
        rx_watermark = uvm_reg_field::type_id::create("rx_watermark");
        rx_watermark.configure(this, 8, 8, "RW", 0, 8'h0, 1, 1, 0);
        spien = uvm_reg_field::type_id::create("spien");
        spien.configure(this, 1, 31, "RW", 0, 1'b0, 1, 1, 0);
        output_en = uvm_reg_field::type_id::create("output_en");
        output_en.configure(this, 1, 30, "RW", 0, 1'b0, 1, 1, 0);
    endfunction
endclass

// ─── STATUS register (0x14) ───
class chs_ral_spi_status extends uvm_reg;
    `uvm_object_utils(chs_ral_spi_status)

    uvm_reg_field txqd;
    uvm_reg_field rxqd;
    uvm_reg_field txwm;
    uvm_reg_field rxwm;
    uvm_reg_field byteorder;
    uvm_reg_field rxstall;
    uvm_reg_field txfull;
    uvm_reg_field rxempty;
    uvm_reg_field active;
    uvm_reg_field ready;

    function new(string name = "chs_ral_spi_status");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        txqd     = uvm_reg_field::type_id::create("txqd");
        txqd.configure(this, 8, 0, "RO", 0, 8'h0, 1, 0, 0);
        rxqd     = uvm_reg_field::type_id::create("rxqd");
        rxqd.configure(this, 8, 8, "RO", 0, 8'h0, 1, 0, 0);
        txfull   = uvm_reg_field::type_id::create("txfull");
        txfull.configure(this, 1, 24, "RO", 0, 1'b0, 1, 0, 0);
        rxempty  = uvm_reg_field::type_id::create("rxempty");
        rxempty.configure(this, 1, 25, "RO", 0, 1'b1, 1, 0, 0);
        active   = uvm_reg_field::type_id::create("active");
        active.configure(this, 1, 30, "RO", 0, 1'b0, 1, 0, 0);
        ready    = uvm_reg_field::type_id::create("ready");
        ready.configure(this, 1, 31, "RO", 0, 1'b1, 1, 0, 0);
    endfunction
endclass

// ─── CONFIGOPTS register (0x18) ───
class chs_ral_spi_configopts extends uvm_reg;
    `uvm_object_utils(chs_ral_spi_configopts)

    rand uvm_reg_field clkdiv;
    rand uvm_reg_field csnlead;
    rand uvm_reg_field csntrail;
    rand uvm_reg_field csnidle;
    rand uvm_reg_field cpol;
    rand uvm_reg_field cpha;

    function new(string name = "chs_ral_spi_configopts");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        clkdiv   = uvm_reg_field::type_id::create("clkdiv");
        clkdiv.configure(this, 16, 0, "RW", 0, 16'd24, 1, 1, 0);
        csnlead  = uvm_reg_field::type_id::create("csnlead");
        csnlead.configure(this, 4, 16, "RW", 0, 4'd4, 1, 1, 0);
        csntrail = uvm_reg_field::type_id::create("csntrail");
        csntrail.configure(this, 4, 20, "RW", 0, 4'd4, 1, 1, 0);
        csnidle  = uvm_reg_field::type_id::create("csnidle");
        csnidle.configure(this, 4, 24, "RW", 0, 4'd4, 1, 1, 0);
        cpol     = uvm_reg_field::type_id::create("cpol");
        cpol.configure(this, 1, 30, "RW", 0, 1'b0, 1, 1, 0);
        cpha     = uvm_reg_field::type_id::create("cpha");
        cpha.configure(this, 1, 31, "RW", 0, 1'b0, 1, 1, 0);
    endfunction
endclass

// ─── CSID register (0x24) ───
class chs_ral_spi_csid extends uvm_reg;
    `uvm_object_utils(chs_ral_spi_csid)

    rand uvm_reg_field csid;

    function new(string name = "chs_ral_spi_csid");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        csid = uvm_reg_field::type_id::create("csid");
        csid.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
    endfunction
endclass

// ─── COMMAND register (0x28) ───
class chs_ral_spi_command extends uvm_reg;
    `uvm_object_utils(chs_ral_spi_command)

    rand uvm_reg_field len;
    rand uvm_reg_field csaat;
    rand uvm_reg_field speed;
    rand uvm_reg_field direction;

    function new(string name = "chs_ral_spi_command");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        len       = uvm_reg_field::type_id::create("len");
        len.configure(this, 9, 0, "WO", 0, 9'h0, 1, 1, 0);
        csaat     = uvm_reg_field::type_id::create("csaat");
        csaat.configure(this, 1, 9, "WO", 0, 1'b0, 1, 1, 0);
        speed     = uvm_reg_field::type_id::create("speed");
        speed.configure(this, 2, 10, "WO", 0, 2'b0, 1, 1, 0);
        direction = uvm_reg_field::type_id::create("direction");
        direction.configure(this, 2, 12, "WO", 0, 2'b01, 1, 1, 0);
    endfunction
endclass

// ─── TXDATA register (0x30) ───
class chs_ral_spi_txdata extends uvm_reg;
    `uvm_object_utils(chs_ral_spi_txdata)

    rand uvm_reg_field data;

    function new(string name = "chs_ral_spi_txdata");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        data = uvm_reg_field::type_id::create("data");
        data.configure(this, 32, 0, "WO", 0, 32'h0, 1, 1, 1);
    endfunction
endclass

// ─── RXDATA register (0x34) ───
class chs_ral_spi_rxdata extends uvm_reg;
    `uvm_object_utils(chs_ral_spi_rxdata)

    uvm_reg_field data;

    function new(string name = "chs_ral_spi_rxdata");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        data = uvm_reg_field::type_id::create("data");
        data.configure(this, 32, 0, "RO", 0, 32'h0, 1, 0, 1);
    endfunction
endclass

// ─── ERR_ENABLE register (0x34 offset area) ───
class chs_ral_spi_err_enable extends uvm_reg;
    `uvm_object_utils(chs_ral_spi_err_enable)

    rand uvm_reg_field overflow;
    rand uvm_reg_field underflow;
    rand uvm_reg_field cmdinval;
    rand uvm_reg_field csidinval;

    function new(string name = "chs_ral_spi_err_enable");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        overflow  = uvm_reg_field::type_id::create("overflow");
        overflow.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
        underflow = uvm_reg_field::type_id::create("underflow");
        underflow.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 0);
        cmdinval  = uvm_reg_field::type_id::create("cmdinval");
        cmdinval.configure(this, 1, 2, "RW", 0, 1'b0, 1, 1, 0);
        csidinval = uvm_reg_field::type_id::create("csidinval");
        csidinval.configure(this, 1, 3, "RW", 0, 1'b0, 1, 1, 0);
    endfunction
endclass

// ─── SPI Host Register Block ───
class chs_ral_spi_block extends uvm_reg_block;
    `uvm_object_utils(chs_ral_spi_block)

    rand chs_ral_spi_control    control;      // 0x10
    rand chs_ral_spi_status     status;       // 0x14
    rand chs_ral_spi_configopts configopts;   // 0x18
    rand chs_ral_spi_csid       csid;         // 0x24
    rand chs_ral_spi_command    command;      // 0x28
         chs_ral_spi_rxdata     rxdata;       // 0x2C
    rand chs_ral_spi_txdata     txdata;       // 0x30
    rand chs_ral_spi_err_enable err_enable;   // 0x34

    uvm_reg_map default_map;

    function new(string name = "chs_ral_spi_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        control = chs_ral_spi_control::type_id::create("control");
        control.configure(this, null, "");
        control.build();

        status = chs_ral_spi_status::type_id::create("status");
        status.configure(this, null, "");
        status.build();

        configopts = chs_ral_spi_configopts::type_id::create("configopts");
        configopts.configure(this, null, "");
        configopts.build();

        csid = chs_ral_spi_csid::type_id::create("csid");
        csid.configure(this, null, "");
        csid.build();

        command = chs_ral_spi_command::type_id::create("command");
        command.configure(this, null, "");
        command.build();

        txdata = chs_ral_spi_txdata::type_id::create("txdata");
        txdata.configure(this, null, "");
        txdata.build();

        rxdata = chs_ral_spi_rxdata::type_id::create("rxdata");
        rxdata.configure(this, null, "");
        rxdata.build();

        err_enable = chs_ral_spi_err_enable::type_id::create("err_enable");
        err_enable.configure(this, null, "");
        err_enable.build();

        // Create map
        default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN);
        default_map.add_reg(control,    'h10, "RW");
        default_map.add_reg(status,     'h14, "RO");
        default_map.add_reg(configopts, 'h18, "RW");
        default_map.add_reg(csid,       'h24, "RW");
        default_map.add_reg(command,    'h28, "WO");
        default_map.add_reg(rxdata,     'h2C, "RO");
        default_map.add_reg(txdata,     'h30, "WO");
        default_map.add_reg(err_enable, 'h34, "RW");

        lock_model();
    endfunction
endclass

`endif // CHS_RAL_SPI_REGS_SV
