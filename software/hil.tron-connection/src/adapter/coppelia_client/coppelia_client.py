"""
Adapter for communicating with CoppeliaSim via ZMQ Remote API.
"""
import time
from typing import Optional
from domain.entities.entities import SensorData, ActuatorCommand

try:
    from coppeliasim_zmqremoteapi_client import RemoteAPIClient
except ImportError:
    RemoteAPIClient = None

class CoppeliaClient:
    def __init__(self) -> None:
        self.client = None
        self.sim = None
        self.connected = False

    def connect(self) -> None:
        if RemoteAPIClient is None:
            raise ImportError(
                "The 'coppeliasim-zmqremoteapi-client' package is required. "
                "Install it using: pip install coppeliasim-zmqremoteapi-client"
            )

        print("Connecting to CoppeliaSim via ZMQ Remote API...")
        try:
            self.client = RemoteAPIClient()
            self.sim = self.client.require('sim')
            self.connected = True
            print("Successfully connected to CoppeliaSim!")
        except Exception as e:
            self.connected = False
            print(f"Failed to connect to CoppeliaSim: {e}")
            raise

    def read_sensors(self) -> Optional[SensorData]:
        if not self.connected:
            return None
        
        # Example implementation - replace with actual sensor reading logic
        # handle = self.sim.getObject('/mySensor')
        # result, data, _ = self.sim.readVisionSensor(handle)
        
        return SensorData(timestamp=time.time(), values=[1.0, 0.5])

    def set_actuator(self, command: ActuatorCommand) -> None:
        if not self.connected:
            return
            
        # Example implementation - replace with actual actuator logic
        # handle = self.sim.getObject('/myJoint')
        # self.sim.setJointTargetVelocity(handle, command.command_value)
        
        print(f"[CoppeliaSim] Actuator {command.actuator_id} set to {command.command_value}")
