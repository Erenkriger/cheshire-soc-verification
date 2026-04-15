# ============================================================================
# sw_wave_setup.tcl
#
# Reusable wave setup for SW-driven Cheshire tests.
# Usage in Questa transcript after vsim opens:
#   do ../sim/sw_wave_setup.tcl
#   sw_wave_for_test test_lvl_easy_uart_hello
#
# Notes:
# - Paths are based on tb_top hierarchy in verif/tb/top/tb_top.sv.
# - Missing signals are skipped automatically.
# ============================================================================

proc _sw_path_candidates {path_expr} {
    set cands [list $path_expr]
    if {[string first "." $path_expr] >= 0} {
        set slash_expr [string map {"." "/"} $path_expr]
        if {$slash_expr ne $path_expr} {
            lappend cands $slash_expr
        }
    }
    return $cands
}

proc _sw_add_exact {sig} {
    foreach cand [_sw_path_candidates $sig] {
        if {[llength [find signals $cand]] > 0} {
            add wave -noupdate $cand
            return
        }
    }
}

proc _sw_add_pattern {pattern} {
    array unset seen
    foreach cand [_sw_path_candidates $pattern] {
        set sigs [find signals -r $cand]
        foreach s $sigs {
            if {![info exists seen($s)]} {
                set seen($s) 1
                add wave -noupdate $s
            }
        }
    }
}

proc _sw_add_group_exact {title sig_list} {
    add wave -noupdate -divider $title
    foreach s $sig_list {
        _sw_add_exact $s
    }
}

proc _sw_add_group_pattern {title pattern_list} {
    add wave -noupdate -divider $title
    foreach p $pattern_list {
        _sw_add_pattern $p
    }
}

proc sw_wave_base {} {
    quietly WaveActivateNextPane {} 0

    _sw_add_group_exact CORE_RESET {
        /tb_top/clk
        /tb_top/rst_n
        /tb_top/boot_mode
        /tb_top/rtc
    }

    _sw_add_group_exact JTAG {
        /tb_top/jtag_tck
        /tb_top/jtag_tms
        /tb_top/jtag_tdi
        /tb_top/jtag_tdo
        /tb_top/jtag_trst_n
    }

    _sw_add_group_exact AXI_LLC {
        /tb_top/axi_llc_vif.awvalid
        /tb_top/axi_llc_vif.awready
        /tb_top/axi_llc_vif.awaddr
        /tb_top/axi_llc_vif.awlen
        /tb_top/axi_llc_vif.awsize
        /tb_top/axi_llc_vif.awatop
        /tb_top/axi_llc_vif.wvalid
        /tb_top/axi_llc_vif.wready
        /tb_top/axi_llc_vif.wdata
        /tb_top/axi_llc_vif.wstrb
        /tb_top/axi_llc_vif.wlast
        /tb_top/axi_llc_vif.bvalid
        /tb_top/axi_llc_vif.bready
        /tb_top/axi_llc_vif.bresp
        /tb_top/axi_llc_vif.arvalid
        /tb_top/axi_llc_vif.arready
        /tb_top/axi_llc_vif.araddr
        /tb_top/axi_llc_vif.arlen
        /tb_top/axi_llc_vif.arsize
        /tb_top/axi_llc_vif.rvalid
        /tb_top/axi_llc_vif.rready
        /tb_top/axi_llc_vif.rdata
        /tb_top/axi_llc_vif.rresp
        /tb_top/axi_llc_vif.rlast
    }

    _sw_add_group_pattern AXI_LLC_FALLBACK {
        /tb_top/axi_llc_vif/*
        /tb_top/axi_llc_mst_req*
        /tb_top/axi_llc_mst_rsp*
    }

    _sw_add_group_exact UART_GPIO {
        /tb_top/uart_tx
        /tb_top/uart_rx
        /tb_top/gpio_i
        /tb_top/gpio_o
        /tb_top/gpio_en_o
    }

    _sw_add_group_exact SPI_I2C {
        /tb_top/spih_sck_o
        /tb_top/spih_csb_o
        /tb_top/spih_sd_o
        /tb_top/spih_sd_i
        /tb_top/spih_sd_en
        /tb_top/i2c_scl_o
        /tb_top/i2c_scl_i
        /tb_top/i2c_scl_en
        /tb_top/i2c_sda_o
        /tb_top/i2c_sda_i
        /tb_top/i2c_sda_en
    }

    _sw_add_group_exact IF_MONITORS {
        /tb_top/uart_vif.tx
        /tb_top/spi_vif.sck
        /tb_top/spi_vif.csb
        /tb_top/i2c_vif.scl_bus
        /tb_top/i2c_vif.sda_bus
        /tb_top/gpio_vif.gpio_o
    }

    _sw_add_group_pattern CORE_INTERNAL {
        /tb_top/dut/gen_cva6_cores*/i_core_cva6/*pc*
        /tb_top/dut/gen_cva6_cores*/i_core_cva6/*commit*
        /tb_top/dut/gen_cva6_cores*/i_core_cva6/*retire*
        /tb_top/dut/gen_cva6_cores*/i_core_cva6/*debug*
        /tb_top/dut/gen_cva6_cores*/i_core_cva6/csr_regfile_i/*scratch*
    }

    _sw_add_group_pattern DEBUG_DM {
        /tb_top/dut/i_dbg_dm_top/*sba*
        /tb_top/dut/i_dbg_dm_top/*dmcontrol*
        /tb_top/dut/i_dbg_dm_top/*dmstatus*
        /tb_top/dut/i_dbg_dmi_jtag/*
    }

    _sw_add_group_pattern CHECKERS {
        /tb_top/i_protocol_checker/*
        /tb_top/i_soc_sva_checker/*
        /tb_top/i_axi_protocol_checker/*
    }

    _sw_add_group_pattern UVM_RUNTIME {
        /uvm_test_top/*
    }

    update
}

proc sw_wave_for_test {test_name} {
    sw_wave_base

    switch -- $test_name {
        test_lvl_easy_uart_hello {
            _sw_add_group_pattern TEST_UART_FOCUS {
                /tb_top/uart*
                /tb_top/uart_vif/*
            }
        }

        test_lvl_easy_gpio_basic {
            _sw_add_group_pattern TEST_GPIO_FOCUS {
                /tb_top/gpio*
                /tb_top/gpio_vif/*
            }
        }

        test_lvl_easy_mem_smoke {
            _sw_add_group_pattern TEST_MEM_FOCUS {
                /tb_top/axi_llc_vif/*
                /tb_top/dut/gen_cva6_cores*/i_core_cva6/*scratch*
            }
        }

        test_lvl_medium_memmap_probe {
            _sw_add_group_pattern TEST_MEMMAP_FOCUS {
                /tb_top/axi_llc_vif/*addr*
                /tb_top/axi_llc_vif/*valid
                /tb_top/axi_llc_vif/*ready
            }
        }

        test_lvl_medium_uart_pattern {
            _sw_add_group_pattern TEST_UART_MEDIUM_FOCUS {
                /tb_top/uart*
                /tb_top/uart_vif/*
                /tb_top/dut/gen_cva6_cores*/i_core_cva6/*scratch*
            }
        }

        test_lvl_medium_gpio_irq_cfg {
            _sw_add_group_pattern TEST_GPIO_IRQ_FOCUS {
                /tb_top/gpio*
                /tb_top/gpio_vif/*
            }
        }

        test_lvl_medium_spi_i2c_cfg {
            _sw_add_group_pattern TEST_SPI_I2C_FOCUS {
                /tb_top/spih*
                /tb_top/spi_vif/*
                /tb_top/i2c*
                /tb_top/i2c_vif/*
            }
        }

        test_lvl_medium_interleave_rw {
            _sw_add_group_pattern TEST_INTERLEAVE_FOCUS {
                /tb_top/axi_llc_vif/*
                /tb_top/gpio*
                /tb_top/spih*
                /tb_top/i2c*
            }
        }

        test_lvl_hard_idma_multi_copy {
            _sw_add_group_pattern TEST_IDMA_FOCUS {
                /tb_top/dut/gen_dma/i_idma/*
                /tb_top/dut/gen_dma/*idma*
                /tb_top/axi_llc_vif/*
            }
        }

        test_lvl_hard_spm_dram_march_mix {
            _sw_add_group_pattern TEST_MARCH_FOCUS {
                /tb_top/axi_llc_vif/*
                /tb_top/dut/gen_cva6_cores*/i_core_cva6/csr_regfile_i/*scratch*
            }
        }

        test_lvl_hard_longrun_protocol_mix {
            _sw_add_group_pattern TEST_LONGRUN_FOCUS {
                /tb_top/axi_llc_vif/*
                /tb_top/uart*
                /tb_top/gpio*
                /tb_top/spih*
                /tb_top/i2c*
            }
        }

        test_lvl_hard_periph_stress_matrix {
            _sw_add_group_pattern TEST_STRESS_MATRIX_FOCUS {
                /tb_top/gpio*
                /tb_top/uart*
                /tb_top/spih*
                /tb_top/i2c*
                /tb_top/axi_llc_vif/*
            }
        }

        test_lvl_hard_recovery_resilience {
            _sw_add_group_pattern TEST_RECOVERY_FOCUS {
                /tb_top/uart*
                /tb_top/spih*
                /tb_top/i2c*
                /tb_top/gpio*
            }
        }

        default {
            puts [format {[sw_wave_for_test] Unknown test_name=%s. Base waves added only.} $test_name]
        }
    }

    update
}
