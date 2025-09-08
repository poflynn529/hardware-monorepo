from dataclasses import dataclass, field
from typing import Callable, Any
from collections import deque

from cocotb.result import TestSuccess

@dataclass
class BaseScoreboard:

    process_transaction_callback: Callable[[Any], Any]
    expected_matches: int

    expect_queue: deque = field(default_factory=deque, init=False, repr=False)
    receive_queue: deque = field(default_factory=deque, init=False, repr=False)
    received_matches: int = field(default=0, init=False, repr=False)

    def _resolve_queues(self) -> None:
        while self.expect_queue and self.receive_queue:
            if self.expect_queue[0] == self.receive_queue[0]:
                self.expect_queue.popleft()
                self.receive_queue.popleft()
                print("Match!")
                self.received_matches += 1
            else:
                raise ValueError(f"Scoreboard mismatch: expected {self.expect_queue[0]}, received {self.receive_queue[0]}")
            
        if self.received_matches == self.expected_matches:
            raise TestSuccess()

    def expect_transaction(self, transaction) -> None:
        self.expect_queue.append(self.process_transaction_callback(transaction))
        self._resolve_queues()

    def receive_transaction(self, transaction) -> None:
        self.receive_queue.append(transaction)
        self._resolve_queues()
