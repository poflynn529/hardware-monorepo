from typing import Callable, Any, Union
from abc import abstractmethod
from dataclasses import dataclass, field

import cocotb
from cocotb.task import Task
from cocotb.clock import Clock
from cocotb.handle import LogicObject, LogicArrayObject

@dataclass
class BaseMonitor:
    clock: Clock
    port: Union[LogicObject, LogicArrayObject]
    receive_callback: Callable[[Any], None]

    _task: Task = field(default=None, init=False, repr=False)
    _config: dict[str, Any] = field(default=None, init=False, repr=False)

    @abstractmethod
    async def _receive(self) -> Any:
        pass

    def set_config(self, config: dict[str, Any]):
        assert isinstance(config, dict)
        self._config = config

    def start(self) -> None:
        if self._task is None:
            self._task = cocotb.start_soon(self._receive())
