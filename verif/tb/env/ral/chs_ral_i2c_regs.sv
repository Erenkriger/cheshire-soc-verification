// ============================================================================
// chs_ral_i2c_regs.sv — I2C Register Block (RAL)
//
// Base: 0x0300_3000 (OpenTitan I2C)
// Registers: CTRL, STATUS, FMTFIFO, RXFIFO, FIFO_CTRL, OVRD, TIMING0-4
// ============================================================================

`ifndef CHS_RAL_I2C_REGS_SV
`define CHS_RAL_I2C_REGS_SV

// ─── CTRL register (0x04) ───
class chs_ral_i2c_ctrl extends uvm_reg;
    `uvm_object_utils(chs_ral_i2c_ctrl)

    rand uvm_reg_field enablehost;
    rand uvm_reg_field enabletarget;

    function new(string name = "chs_ral_i2c_ctrl");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        enablehost = uvm_reg_field::type_id::create("enablehost");
        enablehost.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
        enabletarget = uvm_reg_field::type_id::create("enabletarget");
        enabletarget.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 0);
    endfunction
endclass

// ─── STATUS register (0x08) ───
class chs_ral_i2c_status extends uvm_reg;
    `uvm_object_utils(chs_ral_i2c_status)

    uvm_reg_field fmtfull;
    uvm_reg_field rxfull;
    uvm_reg_field fmtempty;
    uvm_reg_field hostidle;
    uvm_reg_field targetidle;
    uvm_reg_field rxempty;

    function new(string name = "chs_ral_i2c_status");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        fmtfull    = uvm_reg_field::type_id::create("fmtfull");
        fmtfull.configure(this, 1, 0, "RO", 0, 1'b0, 1, 0, 0);
        rxfull     = uvm_reg_field::type_id::create("rxfull");
        rxfull.configure(this, 1, 1, "RO", 0, 1'b0, 1, 0, 0);
        fmtempty   = uvm_reg_field::type_id::create("fmtempty");
        fmtempty.configure(this, 1, 2, "RO", 0, 1'b1, 1, 0, 0);
        hostidle   = uvm_reg_field::type_id::create("hostidle");
        hostidle.configure(this, 1, 3, "RO", 0, 1'b1, 1, 0, 0);
        targetidle = uvm_reg_field::type_id::create("targetidle");
        targetidle.configure(this, 1, 4, "RO", 0, 1'b1, 1, 0, 0);
        rxempty    = uvm_reg_field::type_id::create("rxempty");
        rxempty.configure(this, 1, 5, "RO", 0, 1'b1, 1, 0, 0);
    endfunction
endclass

// ─── FMTFIFO register (0x24) ───
class chs_ral_i2c_fmtfifo extends uvm_reg;
    `uvm_object_utils(chs_ral_i2c_fmtfifo)

    rand uvm_reg_field fbyte;
    rand uvm_reg_field start_f;
    rand uvm_reg_field stop_f;
    rand uvm_reg_field readb;
    rand uvm_reg_field rcont;
    rand uvm_reg_field nakok;

    function new(string name = "chs_ral_i2c_fmtfifo");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        fbyte   = uvm_reg_field::type_id::create("fbyte");
        fbyte.configure(this, 8, 0, "WO", 0, 8'h0, 1, 1, 0);
        start_f = uvm_reg_field::type_id::create("start_f");
        start_f.configure(this, 1, 8, "WO", 0, 1'b0, 1, 1, 0);
        stop_f  = uvm_reg_field::type_id::create("stop_f");
        stop_f.configure(this, 1, 9, "WO", 0, 1'b0, 1, 1, 0);
        readb   = uvm_reg_field::type_id::create("readb");
        readb.configure(this, 1, 10, "WO", 0, 1'b0, 1, 1, 0);
        rcont   = uvm_reg_field::type_id::create("rcont");
        rcont.configure(this, 1, 11, "WO", 0, 1'b0, 1, 1, 0);
        nakok   = uvm_reg_field::type_id::create("nakok");
        nakok.configure(this, 1, 12, "WO", 0, 1'b0, 1, 1, 0);
    endfunction
endclass

// ─── RXFIFO register (0x28) ───
class chs_ral_i2c_rxfifo extends uvm_reg;
    `uvm_object_utils(chs_ral_i2c_rxfifo)

    uvm_reg_field rdata;

    function new(string name = "chs_ral_i2c_rxfifo");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        rdata = uvm_reg_field::type_id::create("rdata");
        rdata.configure(this, 8, 0, "RO", 1, 8'h0, 1, 0, 1);
    endfunction
endclass

// ─── FIFO_CTRL register (0x2C) ───
class chs_ral_i2c_fifo_ctrl extends uvm_reg;
    `uvm_object_utils(chs_ral_i2c_fifo_ctrl)

    rand uvm_reg_field rxrst;
    rand uvm_reg_field fmtrst;

    function new(string name = "chs_ral_i2c_fifo_ctrl");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        rxrst  = uvm_reg_field::type_id::create("rxrst");
        rxrst.configure(this, 1, 0, "WO", 0, 1'b0, 1, 1, 0);
        fmtrst = uvm_reg_field::type_id::create("fmtrst");
        fmtrst.configure(this, 1, 1, "WO", 0, 1'b0, 1, 1, 0);
    endfunction
endclass

// ─── TIMING0 register (0x7C) ───
class chs_ral_i2c_timing0 extends uvm_reg;
    `uvm_object_utils(chs_ral_i2c_timing0)

    rand uvm_reg_field thigh;
    rand uvm_reg_field tlow;

    function new(string name = "chs_ral_i2c_timing0");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        thigh = uvm_reg_field::type_id::create("thigh");
        thigh.configure(this, 16, 0, "RW", 0, 16'd100, 1, 1, 0);
        tlow  = uvm_reg_field::type_id::create("tlow");
        tlow.configure(this, 16, 16, "RW", 0, 16'd100, 1, 1, 0);
    endfunction
endclass

// ─── I2C Register Block ───
class chs_ral_i2c_block extends uvm_reg_block;
    `uvm_object_utils(chs_ral_i2c_block)

    rand chs_ral_i2c_ctrl      ctrl;       // 0x10
         chs_ral_i2c_status    status;     // 0x14
         chs_ral_i2c_rxfifo    rxfifo;     // 0x18 (RDATA)
    rand chs_ral_i2c_fmtfifo   fmtfifo;   // 0x1C (FDATA)
    rand chs_ral_i2c_fifo_ctrl fifo_ctrl;  // 0x20
    rand chs_ral_i2c_timing0   timing0;    // 0x30

    uvm_reg_map default_map;

    function new(string name = "chs_ral_i2c_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        ctrl = chs_ral_i2c_ctrl::type_id::create("ctrl");
        ctrl.configure(this, null, "");
        ctrl.build();

        status = chs_ral_i2c_status::type_id::create("status");
        status.configure(this, null, "");
        status.build();

        fmtfifo = chs_ral_i2c_fmtfifo::type_id::create("fmtfifo");
        fmtfifo.configure(this, null, "");
        fmtfifo.build();

        rxfifo = chs_ral_i2c_rxfifo::type_id::create("rxfifo");
        rxfifo.configure(this, null, "");
        rxfifo.build();

        fifo_ctrl = chs_ral_i2c_fifo_ctrl::type_id::create("fifo_ctrl");
        fifo_ctrl.configure(this, null, "");
        fifo_ctrl.build();

        timing0 = chs_ral_i2c_timing0::type_id::create("timing0");
        timing0.configure(this, null, "");
        timing0.build();

        default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN);
        default_map.add_reg(ctrl,      'h10, "RW");
        default_map.add_reg(status,    'h14, "RO");
        default_map.add_reg(rxfifo,    'h18, "RO");
        default_map.add_reg(fmtfifo,   'h1C, "WO");
        default_map.add_reg(fifo_ctrl, 'h20, "WO");
        default_map.add_reg(timing0,   'h30, "RW");

        lock_model();
    endfunction
endclass

`endif // CHS_RAL_I2C_REGS_SV
