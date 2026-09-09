import serial

class Uart:
    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 2.0):
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.ser = None

    def connect(self):
        try:
            self.ser = serial.Serial(self.port, self.baudrate, timeout=self.timeout)
            print(f"[UartAdapter] Connected to {self.port} at {self.baudrate} baud.")
        except Exception as e:
            raise ConnectionError(f"Failed to connect to {self.port}: {e}")

    def disconnect(self):
        if self.ser and self.ser.is_open:
            self.ser.close()
            print(f"[UartAdapter] Disconnected from {self.port}.")

    def send_bytes(self, data: bytes):
        """Sends bytes over UART."""
        if not self.ser or not self.ser.is_open:
            raise ConnectionError("UART is not connected.")
        self.ser.write(data)
        self.ser.flush()

    def receive_bytes(self, num_bytes: int) -> bytes:
        """Reads a specific number of bytes from UART. Blocks until timeout."""
        if not self.ser or not self.ser.is_open:
            raise ConnectionError("UART is not connected.")
        response = self.ser.read(num_bytes)
        return response
