# ============================================================================
# Makefile — Cheshire SoC UVM Verification Environment
#
# Usage:
#   make compile          — Compile Cheshire RTL + UVM TB (QuestaSim)
#   make sim TEST=<name>  — Run simulation with a specific UVM test
#   make sim_gui          — Run with GUI waveform viewer
#   make vcs_compile      — Compile with VCS
#   make vcs_sim          — Run with VCS
#   make clean            — Clean build artifacts
#
# Examples:
#   make sim TEST=chs_sanity_test
#   make sim TEST=chs_jtag_boot_test +BOOT_MODE=2
#   make sim TEST=chs_uart_test SEED=12345
# ============================================================================

# ─── Paths ───────────────────────────────────────────────────────────────
VERIF_ROOT := $(shell realpath $(dir $(lastword $(MAKEFILE_LIST))))
CHS_ROOT   := $(VERIF_ROOT)/../cheshire
BENDER     ?= bender -d $(CHS_ROOT)

# Header roots used by cheshire/hw/include/cheshire/typedef.svh
AXI_INC_DIR   := $(firstword $(wildcard $(CHS_ROOT)/.bender/git/checkouts/axi-*/include))
REGIF_INC_DIR := $(firstword $(wildcard $(CHS_ROOT)/.bender/git/checkouts/register_interface-*/include))

# UVM source (Questa ships UVM; for others, set UVM_HOME)
UVM_HOME   ?= $(QUESTA_HOME)/verilog_src/uvm-1.2

# ─── Tool Config ─────────────────────────────────────────────────────────
VLOG       ?= vlog
VSIM       ?= vsim
VLOGAN     ?= vlogan
VCS        ?= vcs

CXX        ?= g++
CXX_PATH   := $(shell which $(CXX))

VLOG_FLAGS  := -suppress 2583 -suppress 13314 -timescale 1ns/1ps -sv
VSIM_FLAGS  := -64 -t 1ps -suppress 12110

# Bender flags
CHS_BENDER_FLAGS := -t rtl -t cva6 -t cv64a6_imafdchsclic_sv39_wb -t sim -t test

# ─── Test Config ─────────────────────────────────────────────────────────
TEST       ?= chs_sanity_test
SEED       ?= random
VERBOSITY  ?= UVM_MEDIUM
SIM_TIME   ?= 10ms
PLUSARGS   ?=

# Compile only firmware-driven verification path when requested.
VLOG_DEFINES :=
ifeq ($(TEST),chs_sw_external_test)
VLOG_DEFINES += +define+CHS_SW_ONLY
endif

# Build directory
BUILD_DIR  := $(VERIF_ROOT)/build
WORK_DIR   := $(BUILD_DIR)/work

# ─── UVM TB File List ────────────────────────────────────────────────────
TB_TOP_FILES := \
	$(VERIF_ROOT)/tb/top/chs_protocol_checker.sv \
	$(VERIF_ROOT)/tb/top/chs_soc_sva_checker.sv \
	$(VERIF_ROOT)/tb/top/chs_axi_protocol_checker.sv \
	$(VERIF_ROOT)/tb/top/tb_top.sv

TB_AGENT_DIR := $(VERIF_ROOT)/tb/agents
TB_ENV_DIR   := $(VERIF_ROOT)/tb/env
TB_SEQ_DIR   := $(VERIF_ROOT)/tb/sequences
TB_TEST_DIR  := $(VERIF_ROOT)/tb/tests
TB_RAL_DIR   := $(TB_ENV_DIR)/ral

# Include paths for UVM TB
TB_INCDIRS := \
	+incdir+$(TB_AGENT_DIR)/jtag_agent \
	+incdir+$(TB_AGENT_DIR)/uart_agent \
	+incdir+$(TB_AGENT_DIR)/spi_agent  \
	+incdir+$(TB_AGENT_DIR)/i2c_agent  \
	+incdir+$(TB_AGENT_DIR)/gpio_agent \
	+incdir+$(TB_AGENT_DIR)/axi_agent  \
	+incdir+$(TB_AGENT_DIR)/slink_agent \
	+incdir+$(TB_AGENT_DIR)/vga_agent  \
	+incdir+$(TB_AGENT_DIR)/usb_agent  \
	+incdir+$(TB_ENV_DIR)  \
	+incdir+$(TB_RAL_DIR)  \
	+incdir+$(TB_SEQ_DIR)  \
	+incdir+$(TB_SEQ_DIR)/ip  \
	+incdir+$(TB_SEQ_DIR)/virtual \
	+incdir+$(TB_TEST_DIR) \
	+incdir+$(CHS_ROOT)/hw/include \
	+incdir+$(AXI_INC_DIR) \
	+incdir+$(REGIF_INC_DIR)

# UVM TB package files (order matters: agents → env → sequences → tests)
TB_PKGS := \
	$(TB_AGENT_DIR)/jtag_agent/jtag_pkg.sv \
	$(TB_AGENT_DIR)/uart_agent/uart_pkg.sv \
	$(TB_AGENT_DIR)/spi_agent/spi_pkg.sv   \
	$(TB_AGENT_DIR)/i2c_agent/i2c_pkg.sv   \
	$(TB_AGENT_DIR)/gpio_agent/gpio_pkg.sv \
	$(TB_AGENT_DIR)/axi_agent/chs_axi_pkg.sv \
	$(TB_AGENT_DIR)/slink_agent/slink_pkg.sv \
	$(TB_AGENT_DIR)/vga_agent/vga_pkg.sv   \
	$(TB_AGENT_DIR)/usb_agent/usb_pkg.sv   \
	$(TB_RAL_DIR)/chs_ral_pkg.sv \
	$(TB_ENV_DIR)/chs_env_pkg.sv \
	$(TB_SEQ_DIR)/chs_seq_pkg.sv \
	$(TB_TEST_DIR)/chs_test_pkg.sv

# Interface files (must be compiled before packages that reference them)
TB_IFS := \
	$(TB_AGENT_DIR)/jtag_agent/jtag_if.sv \
	$(TB_AGENT_DIR)/uart_agent/uart_if.sv \
	$(TB_AGENT_DIR)/spi_agent/spi_if.sv   \
	$(TB_AGENT_DIR)/i2c_agent/i2c_if.sv   \
	$(TB_AGENT_DIR)/gpio_agent/gpio_if.sv \
	$(TB_AGENT_DIR)/axi_agent/chs_axi_if.sv \
	$(TB_AGENT_DIR)/slink_agent/slink_if.sv \
	$(TB_AGENT_DIR)/vga_agent/vga_if.sv   \
	$(TB_AGENT_DIR)/usb_agent/usb_if.sv

# ╔═══════════════════════════════════════════════════════════════╗
# ║  QuestaSim Flow                                               ║
# ╚═══════════════════════════════════════════════════════════════╝

# Generate Cheshire RTL compile script via Bender (or reuse existing if offline)
EXISTING_RTL_SCRIPT := $(CHS_ROOT)/target/sim/vsim/compile.cheshire_soc.tcl

$(BUILD_DIR)/compile_chs_rtl.tcl: $(CHS_ROOT)/Bender.yml | $(BUILD_DIR)
	@if [ -f "$(EXISTING_RTL_SCRIPT)" ]; then \
		echo "Using existing RTL compile script: $(EXISTING_RTL_SCRIPT)"; \
		cp "$(EXISTING_RTL_SCRIPT)" $@; \
	else \
		echo "Generating RTL compile script via Bender..."; \
		$(BENDER) script vsim $(CHS_BENDER_FLAGS) \
			--vlog-arg="$(VLOG_FLAGS)" > $@; \
	fi
	@echo "# ELF Loader (C++ DPI)" >> $@
	@echo 'vlog "$(CHS_ROOT)/target/sim/src/elfloader.cpp" \
		-ccflags "-std=c++11" -cpppath "$(CXX_PATH)"' >> $@

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(WORK_DIR): | $(BUILD_DIR)
	cd $(BUILD_DIR) && vlib work

.PHONY: compile
compile: $(BUILD_DIR)/compile_chs_rtl.tcl | $(WORK_DIR)
	@echo "════════════════════════════════════════════════════"
	@echo "  Step 1/2: Compiling Cheshire RTL"
	@echo "════════════════════════════════════════════════════"
	cd $(BUILD_DIR) && vsim -c -do "source compile_chs_rtl.tcl; quit"
	@echo "════════════════════════════════════════════════════"
	@echo "  Step 2/2: Compiling UVM Testbench"
	@echo "════════════════════════════════════════════════════"
	cd $(BUILD_DIR) && $(VLOG) $(VLOG_FLAGS) \
		$(VLOG_DEFINES) \
		$(TB_INCDIRS) \
		$(TB_IFS) \
		$(TB_PKGS) \
		$(TB_TOP_FILES)

.PHONY: sim
sim: compile
	@echo "════════════════════════════════════════════════════"
	@echo "  Running: +UVM_TESTNAME=$(TEST)"
	@echo "════════════════════════════════════════════════════"
	cd $(BUILD_DIR) && $(VSIM) $(VSIM_FLAGS) \
		-sv_seed $(SEED) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERBOSITY) \
		+UVM_TIMEOUT=$(SIM_TIME) \
		$(PLUSARGS) \
		-do "run -all; quit -f" \
		work.tb_top

.PHONY: sim_gui
sim_gui: compile
	cd $(BUILD_DIR) && $(VSIM) $(VSIM_FLAGS) \
		-sv_seed $(SEED) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERBOSITY) \
		+UVM_TIMEOUT=$(SIM_TIME) \
		$(PLUSARGS) \
		-do "log -r /*; run -all" \
		work.tb_top

# ╔═══════════════════════════════════════════════════════════════╗
# ║  VCS Flow                                                     ║
# ╚═══════════════════════════════════════════════════════════════╝

$(BUILD_DIR)/compile_chs_rtl.sh: $(CHS_ROOT)/Bender.yml | $(BUILD_DIR)
	$(BENDER) script vcs $(CHS_BENDER_FLAGS) \
		--vlog-arg="-kdb -nc -assert svaext +v2k -timescale=1ns/1ps" \
		--vlogan-bin="$(VLOGAN)" > $@
	chmod +x $@

.PHONY: vcs_compile
vcs_compile: $(BUILD_DIR)/compile_chs_rtl.sh | $(BUILD_DIR)
	@echo "════════════════════════════════════════════════════"
	@echo "  VCS: Compiling Cheshire RTL + UVM TB"
	@echo "════════════════════════════════════════════════════"
	cd $(BUILD_DIR) && bash compile_chs_rtl.sh
	cd $(BUILD_DIR) && $(VCS) -full64 -sverilog -ntb_opts uvm-1.2 \
		-timescale=1ns/1ps \
		-kdb -lca \
		-debug_access+all \
		$(TB_INCDIRS) \
		$(TB_IFS) \
		$(TB_PKGS) \
		$(TB_TOP) \
		-top tb_top \
		-o simv

.PHONY: vcs_sim
vcs_sim: vcs_compile
	cd $(BUILD_DIR) && ./simv \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERBOSITY) \
		+UVM_TIMEOUT=$(SIM_TIME) \
		+vcs+lic+wait \
		$(PLUSARGS)

# ╔═══════════════════════════════════════════════════════════════╗
# ║  Utilities                                                     ║
# ╚═══════════════════════════════════════════════════════════════╝

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
	rm -rf csrc simv simv.daidir ucli.key

.PHONY: help
help:
	@echo "═══════════════════════════════════════════════════════════"
	@echo "  Cheshire SoC UVM Verification — Makefile Help"
	@echo "═══════════════════════════════════════════════════════════"
	@echo ""
	@echo "  QuestaSim:"
	@echo "    make compile                    Compile RTL + TB"
	@echo "    make sim TEST=<name>            Run test (batch)"
	@echo "    make sim_gui TEST=<name>        Run test (GUI)"
	@echo ""
	@echo "  VCS:"
	@echo "    make vcs_compile                Compile with VCS"
	@echo "    make vcs_sim TEST=<name>        Run test with VCS"
	@echo ""
	@echo "  Available tests:"
	@echo "    chs_sanity_test      Smoke: IDCODE + GPIO toggle"
	@echo "    chs_jtag_boot_test   JTAG boot sequence"
	@echo "    chs_uart_test        UART TX/RX traffic"
	@echo ""
	@echo "  Options:"
	@echo "    SEED=<n|random>      Random seed (default: random)"
	@echo "    VERBOSITY=<level>    UVM_NONE/LOW/MEDIUM/HIGH/DEBUG"
	@echo "    PLUSARGS='+arg1 ...' Additional plusargs"
	@echo "═══════════════════════════════════════════════════════════"
