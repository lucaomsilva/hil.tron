class DataConverter:
    @staticmethod
    def int32_to_bytes(value: int, byteorder: str = 'little') -> bytes:
        """
        Converts a 32-bit integer into 4 bytes.
        """
        # Ensure value is treated as 32-bit unsigned for bitwise operations
        value = value & 0xFFFFFFFF
        return value.to_bytes(4, byteorder=byteorder)

    @staticmethod
    def bytes_to_int32(byte_data: bytes, byteorder: str = 'little') -> int:
        """
        Converts 4 bytes back into a 32-bit integer.
        """
        if len(byte_data) != 4:
            raise ValueError(f"Expected 4 bytes, got {len(byte_data)}")
        return int.from_bytes(byte_data, byteorder=byteorder)
