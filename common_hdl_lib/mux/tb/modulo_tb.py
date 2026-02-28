import os

import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def test_exhaustive(dut):
    data_width = int(os.environ.get("DATA_WIDTH", "8"))
    modulus    = int(os.environ.get("MODULUS",     "7"))

    for x in range(2**data_width):
        dut.data_i.value = x
        await Timer(1, "ns")

        expected = x % modulus
        naive    = int(dut.naive_o.value)
        barrett  = int(dut.barrett_o.value)

        assert naive == expected, (
            f"naive:   {x} % {modulus} = {expected}, got {naive}"
        )
        assert barrett == expected, (
            f"barrett: {x} % {modulus} = {expected}, got {barrett}"
        )
