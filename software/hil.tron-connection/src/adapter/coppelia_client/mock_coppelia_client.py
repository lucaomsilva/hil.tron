"""
Adapter for communicating with CoppeliaSim via ZMQ Remote API.
"""
import time
from typing import Optional
from domain.entities.entities import SensorData, ActuatorCommand

class MockCoppeliaClient:
    def __init__(self) -> None:
        # Placeholder for coppeliasim_zmqremoteapi_client initialization
        self.connected = False

    def connect(self) -> None:
        print("Connecting to CoppeliaSim...")
        self.connected = True

    def read_sensors(self) -> Optional[SensorData]:
        # Mock reading sensors
        return SensorData(timestamp=time.time(), values=[1.0, 0.5])

    def set_actuator(self, command: ActuatorCommand) -> None:
        # Mock setting actuator
        print(f"Setting {command.actuator_id} to {command.command_value}")
