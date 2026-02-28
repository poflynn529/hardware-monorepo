load("//buck2:verilator_sim.bzl", "verilator_sim")
load("//buck2:cocotb_test.bzl", "cocotb_test")

_COCOTB_LIB_DIR = "/home/poflynn/src/hardware-monorepo/.venv/lib/python3.13/site-packages/cocotb/libs"
_VERILATOR_CPP  = "/home/poflynn/src/hardware-monorepo/.venv/lib/python3.13/site-packages/cocotb/share/lib/verilator/verilator.cpp"
_VENV           = "/home/poflynn/src/hardware-monorepo/.venv"

def modulo_tests(moduli, python_path, data_width = 8):
    for m in moduli:
        verilator_sim(
            name           = "modulo_sim_m{}".format(m),
            top_module     = "modulo_harness",
            deps           = [":modulo_harness"],
            parameters     = {"MODULUS": str(m), "DATA_WIDTH": str(data_width)},
            compile_args   = ["-Wno-fatal"],
            cocotb_lib_dir = _COCOTB_LIB_DIR,
            verilator_cpp  = _VERILATOR_CPP,
        )
        cocotb_test(
            name        = "modulo_test_m{}".format(m),
            sim         = ":modulo_sim_m{}".format(m),
            test_module = "modulo_tb",
            venv        = _VENV,
            python_path = python_path,
            env         = {"MODULUS": str(m), "DATA_WIDTH": str(data_width)},
        )
