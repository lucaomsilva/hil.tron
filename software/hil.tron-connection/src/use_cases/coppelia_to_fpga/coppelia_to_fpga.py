"""
Use case to read state from CoppeliaSim and send it to the FPGA.
"""
from typing import Optional
from domain.entities.entities import SensorData
from adapter.types.types import ICoppeliaClient, IFpgaAdapter
from use_cases.types.types import IUseCase

class CoppeliaToFpgaUseCase(IUseCase):
    def __init__(self, coppelia_client: ICoppeliaClient, fpga_adapter: IFpgaAdapter) -> None:
        self.coppelia_client = coppelia_client
        self.fpga_adapter = fpga_adapter

    def _read_from_coppelia(self) -> Optional[SensorData]:
        return self.coppelia_client.read_sensors()

    def _dispatch_to_fpga(self, data: SensorData) -> None:
        self.fpga_adapter.send_data(data.values)

    def execute(self) -> None:
        sensor_data = self._read_from_coppelia()
        if sensor_data is not None:
            self._dispatch_to_fpga(sensor_data)
