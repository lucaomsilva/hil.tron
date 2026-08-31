"""
Use case to read responses from the FPGA and send commands to CoppeliaSim.
"""
from typing import List, Optional
from domain.entities.entities import ActuatorCommand
from adapter.types.types import IFpgaAdapter, ICoppeliaClient
from use_cases.types.types import IUseCase

class FpgaToCoppeliaUseCase(IUseCase):
    def __init__(self, fpga_adapter: IFpgaAdapter, coppelia_client: ICoppeliaClient) -> None:
        self.fpga_adapter = fpga_adapter
        self.coppelia_client = coppelia_client

    def _read_from_fpga(self) -> Optional[List[float]]:
        return self.fpga_adapter.read_data()

    def _update_coppelia(self, fpga_values: List[float]) -> None:
        if len(fpga_values) > 0:
            command = ActuatorCommand(actuator_id="Joint1", command_value=fpga_values[0])
            self.coppelia_client.set_actuator(command)

    def execute(self) -> None:
        fpga_response = self._read_from_fpga()
        if fpga_response is not None:
            self._update_coppelia(fpga_response)
