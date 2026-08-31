from typing import Protocol, List, Optional
from domain.entities.entities import SensorData, ActuatorCommand

class ICoppeliaClient(Protocol):
    def connect(self) -> None:
        ...

    def read_sensors(self) -> Optional[SensorData]:
        ...

    def set_actuator(self, command: ActuatorCommand) -> None:
        ...

class IFpgaAdapter(Protocol):
    def connect(self) -> None:
        ...

    def send_data(self, values: List[float]) -> None:
        ...

    def read_data(self) -> Optional[List[float]]:
        ...
