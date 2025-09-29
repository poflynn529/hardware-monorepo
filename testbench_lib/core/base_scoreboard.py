from typing import Callable, Any
from collections import deque

from cocotb.triggers import Event

class BaseScoreboard:

    def __init__(self, process_transaction_callback: Callable[[Any], Any]):
        assert callable(process_transaction_callback)
        self._process_transaction_callback: Callable[[Any], Any] = process_transaction_callback
        self._config: dict[str, Any] = {}
        self._expect_queue: deque = deque()
        self._receive_queue: deque = deque()
        self._received_matches: int = 0
        self._done: Event = Event()

    def _resolve_queues(self) -> None:
        while self._expect_queue and self._receive_queue:
            if self._expect_queue[0] == self._receive_queue[0]:
                self._expect_queue.popleft()
                self._receive_queue.popleft()
                self._received_matches += 1
            else:
                raise ValueError(f"Scoreboard mismatch: expected {self._expect_queue[0]}, received {self._receive_queue[0]}")
            
        if self._received_matches == self._config["scoreboard_expected_matches"]:
            self._done.set()

    def set_config(self, config: dict[str, Any]):
        assert isinstance(config, dict)
        self._config = config

    def expect_transaction(self, transaction) -> None:
        assert self._process_transaction_callback is not None
        self._expect_queue.append(self._process_transaction_callback(transaction))
        self._resolve_queues()

    def receive_transaction(self, transaction) -> None:
        self._receive_queue.append(transaction)
        self._resolve_queues()

    async def start(self):
        await self._done.wait()
