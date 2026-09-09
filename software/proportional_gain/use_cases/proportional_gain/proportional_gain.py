from domain.entities.data_converter import DataConverter
from domain.entities.gain_validator import GainValidator
from adapter.uart.uart import Uart

class ProportionalGain:
    def __init__(self, uart: Uart):
        self.uart = uart

    def execute(self, gain_value: int, reference_value: int, input_value: int) -> bool:
        """
        Executes the proportional-gain test over UART.

        The gain is not transmitted to the FPGA - it is only used locally to
        compute the expected result. Transmission order: reference, then input.
        The FPGA is expected to reply with a single 32-bit word:
        output = gain * (reference - input).
        """
        print(f"\n--- Starting Proportional Gain Test ---")
        print(f"Gain Value (local only): {gain_value} (0x{gain_value & 0xFFFFFFFF:08X})")
        print(f"Reference Value: {reference_value} (0x{reference_value & 0xFFFFFFFF:08X})")
        print(f"Input Value: {input_value} (0x{input_value & 0xFFFFFFFF:08X})")

        # 1. Convert to bytes
        ref_bytes = DataConverter.int32_to_bytes(reference_value)
        input_bytes = DataConverter.int32_to_bytes(input_value)

        # 2. Transmit Reference Value
        print(f"-> Sending Reference Bytes: {ref_bytes.hex().upper()}")
        input("press ENTER to send")
        self.uart.send_bytes(ref_bytes)

        # 3. Transmit Input Value
        print(f"-> Sending Input Bytes: {input_bytes.hex().upper()}")
        self.uart.send_bytes(input_bytes)

        # 4. Receive Result (4 bytes for a 32-bit result)
        print("<- Waiting for 32-bit Result (4 bytes)...")
        result_bytes = self.uart.receive_bytes(4)

        if len(result_bytes) < 4:
            print(f"[ERROR] Received only {len(result_bytes)} bytes. Timeout?")
            return False

        print(f"<- Received Result Bytes: {result_bytes.hex().upper()}")

        # 5. Convert received bytes back to integer
        received_int = DataConverter.bytes_to_int32(result_bytes)
        print(f"Received Integer: {received_int} (0x{received_int:08X})")

        # 6. Validate
        is_valid = GainValidator.validate(gain_value, reference_value, input_value, received_int)

        if is_valid:
            print("Status: SUCCESS ✅ - FPGA calculation matches expected result.")
        else:
            # Show expected for debugging
            expected = (gain_value * (reference_value - input_value)) & 0xFFFFFFFF
            print(f"Status: MISMATCH ❌ - Expected {expected} (0x{expected:08X})")

        return is_valid
