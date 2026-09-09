class GainValidator:
    @staticmethod
    def validate(gain: int, reference_value: int, input_value: int, received_result: int) -> bool:
        """
        Checks if the received result matches the expected proportional-gain output:
        output = gain * (reference - input).
        Note: Simulating 32-bit unsigned arithmetic overflow, same as the FPGA.
        """
        expected_result = (gain * (reference_value - input_value)) & 0xFFFFFFFF
        return received_result == expected_result
