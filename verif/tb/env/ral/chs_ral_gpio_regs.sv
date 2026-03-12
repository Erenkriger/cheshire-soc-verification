// ============================================================================
// chs_ral_gpio_regs.sv — GPIO Register Block (RAL)
//
// Base: 0x0300_5000 (OpenTitan GPIO)
// Registers: INTR_STATE, INTR_ENABLE, DATA_IN, DIRECT_OUT, DIRECT_OE,
//            MASKED_OUT_LOWER, MASKED_OUT_UPPER, MASKED_OE_LOWER, MASKED_OE_UPPER
// ============================================================================

`ifndef CHS_RAL_GPIO_REGS_SV
`define CHS_RAL_GPIO_REGS_SV

// ─── INTR_STATE register (0x00) ───
class chs_ral_gpio_intr_state extends uvm_reg;
    `uvm_object_utils(chs_ral_gpio_intr_state)

    rand uvm_reg_field gpio_intr;

    function new(string name = "chs_ral_gpio_intr_state");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        gpio_intr = uvm_reg_field::type_id::create("gpio_intr");
        gpio_intr.configure(this, 32, 0, "W1C", 1, 32'h0, 1, 1, 1);
    endfunction
endclass

// ─── INTR_ENABLE register (0x04) ───
class chs_ral_gpio_intr_enable extends uvm_reg;
    `uvm_object_utils(chs_ral_gpio_intr_enable)

    rand uvm_reg_field gpio_en;

    function new(string name = "chs_ral_gpio_intr_enable");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        gpio_en = uvm_reg_field::type_id::create("gpio_en");
        gpio_en.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
    endfunction
endclass

// ─── INTR_CTRL_EN_RISING register (0x2C) ───
class chs_ral_gpio_intr_ctrl_en_rising extends uvm_reg;
    `uvm_object_utils(chs_ral_gpio_intr_ctrl_en_rising)

    rand uvm_reg_field rising_en;

    function new(string name = "chs_ral_gpio_intr_ctrl_en_rising");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        rising_en = uvm_reg_field::type_id::create("rising_en");
        rising_en.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
    endfunction
endclass

// ─── INTR_CTRL_EN_FALLING register (0x30) ───
class chs_ral_gpio_intr_ctrl_en_falling extends uvm_reg;
    `uvm_object_utils(chs_ral_gpio_intr_ctrl_en_falling)

    rand uvm_reg_field falling_en;

    function new(string name = "chs_ral_gpio_intr_ctrl_en_falling");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        falling_en = uvm_reg_field::type_id::create("falling_en");
        falling_en.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
    endfunction
endclass

// ─── DATA_IN register (0x10) ───
class chs_ral_gpio_data_in extends uvm_reg;
    `uvm_object_utils(chs_ral_gpio_data_in)

    uvm_reg_field data;

    function new(string name = "chs_ral_gpio_data_in");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        data = uvm_reg_field::type_id::create("data");
        data.configure(this, 32, 0, "RO", 0, 32'h0, 1, 0, 1);
    endfunction
endclass

// ─── DIRECT_OUT register (0x14) ───
class chs_ral_gpio_direct_out extends uvm_reg;
    `uvm_object_utils(chs_ral_gpio_direct_out)

    rand uvm_reg_field out_val;

    function new(string name = "chs_ral_gpio_direct_out");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        out_val = uvm_reg_field::type_id::create("out_val");
        out_val.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
    endfunction
endclass

// ─── DIRECT_OE register (0x20) — output enable ───
class chs_ral_gpio_direct_oe extends uvm_reg;
    `uvm_object_utils(chs_ral_gpio_direct_oe)

    rand uvm_reg_field oe_val;

    function new(string name = "chs_ral_gpio_direct_oe");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        oe_val = uvm_reg_field::type_id::create("oe_val");
        oe_val.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
    endfunction
endclass

// ─── GPIO Register Block ───
class chs_ral_gpio_block extends uvm_reg_block;
    `uvm_object_utils(chs_ral_gpio_block)

    rand chs_ral_gpio_intr_state           intr_state;             // 0x00
    rand chs_ral_gpio_intr_enable          intr_enable;            // 0x04
    rand chs_ral_gpio_intr_ctrl_en_rising  intr_ctrl_en_rising;    // 0x2C
    rand chs_ral_gpio_intr_ctrl_en_falling intr_ctrl_en_falling;   // 0x30
         chs_ral_gpio_data_in              data_in;                // 0x10
    rand chs_ral_gpio_direct_out           direct_out;             // 0x14
    rand chs_ral_gpio_direct_oe            direct_oe;              // 0x20

    uvm_reg_map default_map;

    function new(string name = "chs_ral_gpio_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        intr_state = chs_ral_gpio_intr_state::type_id::create("intr_state");
        intr_state.configure(this, null, "");
        intr_state.build();

        intr_enable = chs_ral_gpio_intr_enable::type_id::create("intr_enable");
        intr_enable.configure(this, null, "");
        intr_enable.build();

        intr_ctrl_en_rising = chs_ral_gpio_intr_ctrl_en_rising::type_id::create("intr_ctrl_en_rising");
        intr_ctrl_en_rising.configure(this, null, "");
        intr_ctrl_en_rising.build();

        intr_ctrl_en_falling = chs_ral_gpio_intr_ctrl_en_falling::type_id::create("intr_ctrl_en_falling");
        intr_ctrl_en_falling.configure(this, null, "");
        intr_ctrl_en_falling.build();

        data_in = chs_ral_gpio_data_in::type_id::create("data_in");
        data_in.configure(this, null, "");
        data_in.build();

        direct_out = chs_ral_gpio_direct_out::type_id::create("direct_out");
        direct_out.configure(this, null, "");
        direct_out.build();

        direct_oe = chs_ral_gpio_direct_oe::type_id::create("direct_oe");
        direct_oe.configure(this, null, "");
        direct_oe.build();

        default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN);
        default_map.add_reg(intr_state,             'h00, "RW");
        default_map.add_reg(intr_enable,            'h04, "RW");
        default_map.add_reg(intr_ctrl_en_rising,    'h2C, "RW");
        default_map.add_reg(intr_ctrl_en_falling,   'h30, "RW");
        default_map.add_reg(data_in,                'h10, "RO");
        default_map.add_reg(direct_out,             'h14, "RW");
        default_map.add_reg(direct_oe,              'h20, "RW");

        lock_model();
    endfunction
endclass

`endif // CHS_RAL_GPIO_REGS_SV
