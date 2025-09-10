from typing import override, ClassVar
from abc import ABC
from cocotb.handle import ModifiableObject, HierarchyObject

# ------------------------------------------------------------------
#  Wrapper classes for cocotb objects
# ------------------------------------------------------------------

class Signal():
    _h: ModifiableObject
    _type: type

    def __init__(self, handle: ModifiableObject, cast_type: type = int):
        assert type(handle) == ModifiableObject
        self._h = handle
        self._type = cast_type

    def __getattr__(self, name):
        if name == "value":
            return self._type(self._h.value)
        return getattr(self._h, name)

    def __setattr__(self, name, value):
        if name == "_h":
            return super().__setattr__(name, value)
        return setattr(self._h, name, value)

    def width(self) -> int:
        return self._h.value.n_bits

    def typeof(self) -> type:
        return self._type

    @property
    def _handle(self):
        return self._h._handle


class Module():
    _signals: dict[str, Signal]

    def __init__(self, dut: HierarchyObject):
        assert type(dut) == HierarchyObject
        self._signals = {member._name : Signal(member) for member in dut if type(member) == ModifiableObject}

    def __getattr__(self, name: str) -> Signal:
        return self._signals[name]

    def __dir__(self):
        return sorted(self._signals.keys())

    @property
    def signals(self) -> dict[str, Signal]:
        return self._signals


class Bus(ABC):
    signals: ClassVar[tuple[str, ...]] = ()
    _signals: dict[str, Signal]

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

    def __getattr__(self, name: str) -> Signal:
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
