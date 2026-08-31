"""
Entry point for the Hardware-in-the-Loop connection software.
"""
import time
import sys
import os

# Ensure the src directory is in the path for absolute imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from adapter.coppelia_client.coppelia_client import CoppeliaClient
from adapter.fpga_uart.fpga_uart import FpgaUartAdapter
from use_cases.coppelia_to_fpga.coppelia_to_fpga import CoppeliaToFpgaUseCase
from use_cases.fpga_to_coppelia.fpga_to_coppelia import FpgaToCoppeliaUseCase

def main():
    print("Starting HIL Connection...")
    
    # 1. Initialize Adapters
    coppelia_client = CoppeliaClient()
    fpga_adapter = FpgaUartAdapter()
    
    coppelia_client.connect()
    fpga_adapter.connect()
    
    # 2. Initialize Use Cases
    coppelia_to_fpga = CoppeliaToFpgaUseCase(coppelia_client, fpga_adapter)
    fpga_to_coppelia = FpgaToCoppeliaUseCase(fpga_adapter, coppelia_client)
    
    # 3. Start loop
    try:
        while True:
            coppelia_to_fpga.execute()
            fpga_to_coppelia.execute()
            time.sleep(1) # Sleep to avoid spamming the console for now
    except KeyboardInterrupt:
        print("\nStopping HIL Connection...")

if __name__ == "__main__":
    main()
