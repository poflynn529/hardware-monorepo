from typing import Callable, Any
from abc import abstractmethod
from dataclasses import dataclass, field

import cocotb
from cocotb.task import Task
from cocotb.clock import Clock

@dataclass
class BaseMonitor:
    clock: Clock
    port: Any
    receive_callback: Callable[[Any], None]

    _task: Task = field(default=None, init=False, repr=False)

    @abstractmethod
    async def _receive_transactions(self) -> Any:
        pass

    def start(self) -> None:
        if self._task is None:
            self._task = cocotb.start_soon(self._receive())

    def stop(self) -> None:
        if self._task is not None:
            self._task.kill()
            self._task = None
