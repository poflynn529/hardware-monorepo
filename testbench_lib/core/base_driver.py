from random import randint
from collections import deque
from typing import Callable, Any, Union
from abc import abstractmethod
from dataclasses import dataclass, field

import cocotb
from cocotb.triggers import RisingEdge
from cocotb.task import Task
from cocotb.clock import Clock
from cocotb.handle import LogicObject, LogicArrayObject

@dataclass
class BaseDriver:
    clock: Clock
    port: Union[LogicObject, LogicArrayObject]
    expect_callback: Callable[[Any], None]

    _transaction_queue: deque[Any] = field(default=None, init=False, repr=False)
    _task: Task = field(default=None, init=False, repr=False)
    _config: dict[str, Any] = field(default=None, init=False, repr=False)

    def load_transaction_queue(self, transactions: list[Any]) -> None:
        self._transaction_queue = deque(transactions)

    @abstractmethod
    async def _drive_transaction(self, transaction: Any) -> None:
        pass

    async def _send(self) -> None:
        pre_delay_range: range = self._config["driver_pre_delay_range"]
        post_delay_range: range = self._config["driver_post_delay_range"]
        while self._transaction_queue:
            for _ in range(randint(pre_delay_range.start, pre_delay_range.stop)):
                await RisingEdge(self.clock)

            self.expect_callback(self._transaction_queue[0])
            await self._drive_transaction(self._transaction_queue.popleft())

            for _ in range(randint(post_delay_range.start, post_delay_range.stop)):
                await RisingEdge(self.clock)

    def set_config(self, config: dict[str, Any]):
        assert isinstance(config, dict)
        self._config = config

    def start(self) -> None:
        if not self._transaction_queue:
            raise RuntimeError("Transaction queue not loaded.")
        if self._task is None:
            self._task = cocotb.start_soon(self._send())

    def stop(self) -> None:
        if self._task is not None:
            self._task.kill()
            self._task = None
