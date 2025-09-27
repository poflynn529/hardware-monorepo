from typing import Callable, Any
from dataclasses import dataclass

from base_driver import BaseDriver
from base_monitor import BaseMonitor
from base_scoreboard import BaseScoreboard

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.handle import LogicObject

BASE_CONFIG: dict[str, Any] = {
    "scoreboard_expected_matches" : None,
    "clock_period"                : 10,
    "timescale"                   : 'ns',
    "watchdog_timeout_cycles"     : 1000000,
    "monitor_stall_probability"   : 0,
    "driver_pre_delay_range"      : range(0, 10),
    "driver_post_delay_range"     : range(0, 10),
}

@dataclass
class ResetSequence:
    clock: LogicObject
    reset: LogicObject
    num_cycles: int

    async def reset_sequence(self) -> None:
        self.reset.value = 1
        await ClockCycles(self.clock, self.num_cycles)
        self.reset.value = 0
        await RisingEdge(self.clock)


class BaseEnvironment:
    _config: dict[str, Any]
    _scoreboard: BaseScoreboard
    _drivers: dict[str, BaseDriver] = {}
    _driver_transaction_generators: dict[str, BaseDriver] = {}
    _monitors: dict[str, BaseMonitor] = {}
    _resets: list[ResetSequence] = []
    _clock: LogicObject

    def set_configuration(self, config: dict[str, Any]) -> None:
        self._config = config

    def set_clock(self, clock: LogicObject):
        assert isinstance(clock, LogicObject)
        self._clock = clock

    def add_reset(self, reset_sequence: ResetSequence) -> None:
        assert isinstance(reset_sequence, ResetSequence)
        self._resets.append(reset_sequence)

    def add_driver(self, name: str, driver: BaseDriver, transaction_generator: Callable) -> None:
        assert isinstance(driver, BaseDriver)
        assert callable(transaction_generator)
        self._drivers[name] = driver
        self._driver_transaction_generators[name] = transaction_generator

    def set_scoreboard(self, scoreboard) -> None:
        assert isinstance(scoreboard, BaseScoreboard)
        self._scoreboard = scoreboard

    def add_monitor(self, name: str, monitor: BaseMonitor) -> None:
        assert isinstance(monitor, BaseMonitor)
        self._monitors[name] = monitor

    # TODO: Investigate if cocotb already has this built in.
    async def _watchdog(self) -> None:
        await ClockCycles(self._clock, self._config["watchdog_timeout_cycles"])
        raise TimeoutError(f"Simulation timed out after {self._config["watchdog_timeout_cycles"]} clock cycles")

    async def run(self) -> None:
        cocotb.start_soon(Clock(self._clock, self._config["clock_period"], self._config["timescale"]).start(start_high=False))

        self._scoreboard.set_config(self._config)

        for monitor in self._monitors.values():
            monitor.set_config(self._config)
            monitor.start()

        for reset in self._resets:
            await reset.reset_sequence() # TODO: Use Join here to do these in parallel.

        for name, driver in self._drivers.items():
            driver.set_config(self._config)
            driver.load_transaction_queue(self._driver_transaction_generators[name](self._config))
            driver.start()

        await self._watchdog()
