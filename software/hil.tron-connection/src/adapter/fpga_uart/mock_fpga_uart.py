"""
Adapter for serial communication with the FPGA.
"""
from typing import List, Optional

class MockFpgaUartAdapter:
    def __init__(self, port: str = "/dev/ttyUSB0", baudrate: int = 115200) -> None:
        self.port = port
        self.baudrate = baudrate
        self.connected = False

    def connect(self) -> None:
        print(f"Connecting to FPGA on {self.port} at {self.baudrate} baud...")
        self.connected = True

    def send_data(self, values: List[float]) -> None:
        # Mock sending data
        print(f"Sending to FPGA: {values}")

    def read_data(self) -> Optional[List[float]]:
        # Mock receiving data
        return [0.75]
