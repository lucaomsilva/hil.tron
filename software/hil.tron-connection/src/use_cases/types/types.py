from typing import Protocol

class IUseCase(Protocol):
    def execute(self) -> None:
        ...
