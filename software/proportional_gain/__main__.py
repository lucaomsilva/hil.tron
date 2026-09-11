#!/usr/bin/env python3
import sys
import os

# Ensure we can import from the current directory structure
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from adapter.uart.uart import Uart
from use_cases.proportional_gain.proportional_gain import ProportionalGain

def main():
    print("Initializing Clean Architecture Proportional Gain Test...")

    PORT = '/dev/ttyUSB1'
    BAUDRATE = 115200

    uart = Uart(port=PORT, baudrate=BAUDRATE, timeout=2.0)

    try:
        uart.connect()
    except ConnectionError as e:
        print(f"Error: {e}")
        sys.exit(1)

    proportional_gain = ProportionalGain(uart)

    gain_value = int(input("What is the gain value? "))

    try:
        proportional_gain.execute(gain_value=gain_value, reference_value=10, input_value=4)

        # Reference must stay >= input for now, so the error term is non-negative
        proportional_gain.execute(gain_value=gain_value, reference_value=150, input_value=100)

    except Exception as e:
        print(f"An error occurred during execution: {e}")
    finally:
        uart.disconnect()
        print("Test Complete.")

if __name__ == "__main__":
    sys.exit(main())
