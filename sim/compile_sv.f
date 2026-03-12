// ============================================================================
// compile_sv.f — Vivado xvlog file list for SoC UVM project
// Usage:  xvlog -sv -f compile_sv.f -L uvm
// ============================================================================

// ─── Compiler options ───
-sv
-L uvm
+incdir+../tb/agents/axi_agent
+incdir+../tb/agents/apb_agent
+incdir+../tb/agents/spi_agent
+incdir+../tb/agents/uart_agent
+incdir+../tb/agents/i2c_agent
+incdir+../tb/agents/can_agent
+incdir+../tb/agents/jtag_agent
+incdir+../tb/env
+incdir+../tb/sequences/ip
+incdir+../tb/sequences/virtual
+incdir+../tb/sequences
+incdir+../tb/tests
+incdir+../tb/top

// ─── RTL — Core ───
../rtl/core/pll.sv
../rtl/core/power_manager.sv
../rtl/core/dfsu.sv
../rtl/core/rv64gc_core.sv

// ─── RTL — Interconnect ───
../rtl/interconnect/axi_interconnect.sv
../rtl/interconnect/apb_bridge.sv

// ─── RTL — Memory ───
../rtl/mem/rom.sv
../rtl/mem/l3_cache.sv
../rtl/mem/ddr4_controller.sv

// ─── RTL — Peripherals ───
../rtl/peripherals/uart_periph.sv
../rtl/peripherals/spi_periph.sv
../rtl/peripherals/i2c_periph.sv
../rtl/peripherals/can_periph.sv
../rtl/peripherals/jtag_tap.sv
../rtl/peripherals/rtc_periph.sv
../rtl/peripherals/dma_engine.sv
../rtl/peripherals/lvds_periph.sv

// ─── RTL — Top ───
../rtl/soc_top.sv

// ─── TB — Agent Interfaces (must come before packages) ───
../tb/agents/axi_agent/axi_if.sv
../tb/agents/apb_agent/apb_if.sv
../tb/agents/spi_agent/spi_if.sv
../tb/agents/uart_agent/uart_if.sv
../tb/agents/i2c_agent/i2c_if.sv
../tb/agents/can_agent/can_if.sv
../tb/agents/jtag_agent/jtag_if.sv

// ─── TB — Agent Packages ───
../tb/agents/axi_agent/axi_pkg.sv
../tb/agents/apb_agent/apb_pkg.sv
../tb/agents/spi_agent/spi_pkg.sv
../tb/agents/uart_agent/uart_pkg.sv
../tb/agents/i2c_agent/i2c_pkg.sv
../tb/agents/can_agent/can_pkg.sv
../tb/agents/jtag_agent/jtag_pkg.sv

// ─── TB — Environment Package ───
../tb/env/soc_env_pkg.sv

// ─── TB — Sequence Package ───
../tb/sequences/soc_seq_pkg.sv

// ─── TB — Test Package ───
../tb/tests/soc_test_pkg.sv

// ─── TB — Top ───
../tb/top/tb_top.sv