# Hardware-in-the-Loop Performance Tests

This document records the latency and calculation time taken to send randomized data over UART to the FPGA controller, perform the calculations, and receive the result back.

## Test Conditions

- **Baudrate**: 115200 bps
- **Controller Kp**: 10
- **Reference Value**: 500
- **Data Range**: Random integers in [0, 499]

## Results

| Number of Tests | Smallest Time (s) | Biggest Time (s) | Mean Time (s) | Median Time (s) | Successful Tests |
|-----------------|-------------------|------------------|---------------|-----------------|------------------|
| 10              | 0.001882          | 0.002085         | 0.001978      | 0.001957        | 10 / 10          |
| 100             | 0.001774          | 0.002199         | 0.001928      | 0.001914        | 100 / 100        |
| 1000            | 0.001767          | 0.002570         | 0.001992      | 0.001989        | 1000 / 1000      |
| 10000           | 0.001777          | 0.002645         | 0.001972      | 0.001967        | 10000 / 10000    |

### Code

```python
import serial
import time
import struct
import sys
import random
import statistics

def main():
    # Configure the serial port as needed
    port = '/dev/ttyUSB1'
    baudrate = 115200

    try:
        if len(sys.argv) > 1:
            kp = int(sys.argv[1])
        else:
            kp = int(input("Enter proportional gain (Kp): "))

        if len(sys.argv) > 2:
            num_tests = int(sys.argv[2])
        else:
            num_tests = 100
    except ValueError:
        print("Invalid input. Please enter an integer.")
        sys.exit(1)

    try:
        ser = serial.Serial(port, baudrate, timeout=2.0)
    except Exception as e:
        print(f"Error opening serial port: {e}")
        sys.exit(1)

    print(f"Opened {port} at {baudrate} baud.")

    # 1. Send Reference Data (Opcode 0x01)
    reference_value = 500
    ref_bytes = struct.pack('<I', reference_value)
    ref_packet = b'\x01' + ref_bytes
    print(f"Sending reference: {reference_value} (packet: {ref_packet.hex()})")
    ser.write(ref_packet)

    # Give a tiny delay for the FPGA to process the reference if needed
    time.sleep(0.01)

    intervals = []
    success_count = 0

    print(f"\nStarting {num_tests} tests with random data...")

    for i in range(num_tests):
        # Generate random data less than reference value
        data_value = random.randint(0, reference_value - 1)
        data_bytes = struct.pack('<I', data_value)
        data_packet = b'\x00' + data_bytes

        # Measure time
        start_time = time.perf_counter()

        # Send the packet
        ser.write(data_packet)

        # Wait for the 4-byte response from the FPGA
        response = ser.read(4)

        end_time = time.perf_counter()

        if len(response) == 4:
            result_value = struct.unpack('<I', response)[0]
            interval = end_time - start_time
            intervals.append(interval)

            # Verify the result
            error = reference_value - data_value
            expected_result = (kp * error) & 0xFFFFFFFF

            if result_value == expected_result:
                success_count += 1
            else:
                print(f"Test {i+1} FAILED! Data: {data_value}, Expected: {expected_result}, Got: {result_value}")
        else:
            print(f"Test {i+1} FAILED to receive full response. Received {len(response)} bytes.")

    ser.close()

    # Analysis
    if not intervals:
        print("No valid intervals to analyze.")
        return

    print("\n--- Test Verification ---")
    print(f"Successful Tests: {success_count} / {num_tests}")

    smallest = min(intervals)
    biggest = max(intervals)
    mean_val = statistics.mean(intervals)
    median_val = statistics.median(intervals)

    print("\n--- Time Interval Analysis (Seconds) ---")
    print(f"Smallest : {smallest:.6f} s")
    print(f"Biggest  : {biggest:.6f} s")
    print(f"Mean     : {mean_val:.6f} s")
    print(f"Median   : {median_val:.6f} s")

if __name__ == '__main__':
    main()

```

To run, you can execute this script in root path of project:
```bash
#!/bin/bash

# This script runs the python test script for 10, 100, 1000, and 10000 iterations.
# It captures the results and formats them so you can easily copy-paste them into your markdown file.

KP=10
TEST_COUNTS=(10 100 1000 10000)

echo "Running tests to generate data for docs/testing/performance_tests.md..."
echo "Note: You may be prompted for sudo password if your user isn't in the dialout group."
echo ""

for COUNT in "${TEST_COUNTS[@]}"; do
    echo "=========================================="
    echo "Running for $COUNT tests..."
    sudo python3 software/test_interval.py $KP $COUNT > /tmp/fpga_test_${COUNT}.log

    SMALLEST=$(grep "Smallest" /tmp/fpga_test_${COUNT}.log | awk -F': ' '{print $2}' | awk '{print $1}')
    BIGGEST=$(grep "Biggest" /tmp/fpga_test_${COUNT}.log | awk -F': ' '{print $2}' | awk '{print $1}')
    MEAN=$(grep "Mean" /tmp/fpga_test_${COUNT}.log | awk -F': ' '{print $2}' | awk '{print $1}')
    MEDIAN=$(grep "Median" /tmp/fpga_test_${COUNT}.log | awk -F': ' '{print $2}' | awk '{print $1}')
    SUCCESS=$(grep "Successful Tests" /tmp/fpga_test_${COUNT}.log | awk -F': ' '{print $2}')

    echo "| $COUNT | $SMALLEST | $BIGGEST | $MEAN | $MEDIAN | $SUCCESS |"
done

echo "=========================================="
echo "Done! You can copy the markdown table rows above into your docs/testing/performance_tests.md file."
```
