"""
Domain entities representing the system state.
"""
from dataclasses import dataclass
from domain.types.types import Timestamp, SensorValues

@dataclass
class SensorData:
    timestamp: Timestamp
    values: SensorValues

@dataclass
class ActuatorCommand:
    actuator_id: str
    command_value: float
