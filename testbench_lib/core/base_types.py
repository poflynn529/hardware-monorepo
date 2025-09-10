from typing import override

class Bytes(bytes):

    @override
    def __str__(self) -> str:
        return self.hex(" ").upper()
