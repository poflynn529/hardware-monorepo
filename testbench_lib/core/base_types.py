from typing import override, ClassVar, Union
from abc import ABC
from cocotb.handle import LogicObject, LogicArrayObject, HierarchyObject

# ------------------------------------------------------------------
#  Wrapper classes for cocotb objects
# ------------------------------------------------------------------

class Module():
    _signals: dict[str, Union[LogicObject, LogicArrayObject]]

    def __init__(self, dut: HierarchyObject):
        assert type(dut) == HierarchyObject
        self._signals = {member._name : member for member in dut if isinstance(member, (LogicObject, LogicArrayObject))}

    def __getattr__(self, name: str) -> Union[LogicObject, LogicArrayObject]:
        return self._signals[name]

    def __dir__(self):
        return sorted(self._signals.keys())

    @property
    def signals(self) -> dict[str, Union[LogicObject, LogicArrayObject]]:
        return self._signals


class Bus(ABC):
    signals: ClassVar[tuple[str, ...]] = ()
    _signals: dict[str, Union[LogicObject, LogicArrayObject]]

    def __init__(self, module: Module, signals: dict[str, str]):
        if not self.signals:
            raise TypeError("Subclass must define 'signals' as a non-empty tuple of aliases")

        required = set(self.signals)
        actual = set(signals.keys())
        if required != actual:
            missing = sorted(required - actual)
            extra = sorted(actual - required)
            raise ValueError(f"Signal map mismatch. missing: {missing} extra: {extra}")

        self._signals = {alias: module.signals[dut_name] for alias, dut_name in signals.items()}

    def __getattr__(self, name: str) -> Union[LogicObject, LogicArrayObject]:
        return self._signals[name]

    def __dir__(self):
        return sorted(self._signals.keys())

# ------------------------------------------------------------------
#  Wrapper classes for basic data types to extend functionality
# ------------------------------------------------------------------

class Bytes(bytes):

    @override
    def __str__(self) -> str:
        return self.hex(" ").upper()
