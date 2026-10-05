# Hardware-in-the-Loop Fixed-Point Performance Tests

This document records the latency, calculation time, and accuracy validation taken to send randomized data over UART to the FPGA controller using Q16.16 signed fixed-point format, perform the proportional gain calculations, and receive the result back.

## V1 Test (Hardcoded Kp)

*In this test, the proportional gain `Kp` was hardcoded inside the controller module. The test script sent only the setpoint value (opcode `0x01`) before starting the feedback loop.*

### Test Conditions

- **Baudrate**: 115200 bps
- **Controller Kp**: 5.5 (Format: Q16.16 signed `32'h00058000`)
- **Setpoint Value**: 500.0000
- **Data Range**: Random floats in [0.0000, 1000.0000] (testing both positive and negative errors)
- **Precision Limit**: 4 decimal places

## Results

| Number of Tests | Smallest Time (s) | Biggest Time (s) | Mean Time (s) | Median Time (s) | 3rd Quartile (s) | Successful Tests |
|-----------------|-------------------|------------------|---------------|-----------------|------------------|------------------|
| 10              | 0.001822          | 0.001991         | 0.001886      | 0.001874        | 0.001921         | 10 / 10          |
| 100             | 0.001807          | 0.002022         | 0.001892      | 0.001890        | 0.001917         | 100 / 100        |
| 1000            | 0.001774          | 0.002192         | 0.001896      | 0.001886        | 0.001928         | 1000 / 1000      |
| 10000           | 0.001769          | 0.003867         | 0.001902      | 0.001890        | 0.001938         | 10000 / 10000    |

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
            kp_float = float(sys.argv[1])
        else:
            kp_float = float(input("Enter proportional gain (Kp) [e.g. 5.5]: "))
            
        if len(sys.argv) > 2:
            num_tests = int(sys.argv[2])
        else:
            num_tests = 100
    except ValueError:
        print("Invalid input. Please enter a number.")
        sys.exit(1)

    try:
        ser = serial.Serial(port, baudrate, timeout=2.0)
    except Exception as e:
        print(f"Error opening serial port: {e}")
        sys.exit(1)

    print(f"Opened {port} at {baudrate} baud.")

    # 1. Send Setpoint Data (Opcode 0x01)
    # The setpoint is sent as a Q16.16 signed integer
    setpoint_float = 500.0000
    setpoint_q16 = int(setpoint_float * 65536)
    
    setpoint_bytes = struct.pack('<i', setpoint_q16)
    setpoint_packet = b'\x01' + setpoint_bytes
    print(f"Sending setpoint: {setpoint_float:.4f} (packet: {setpoint_packet.hex()})")
    ser.write(setpoint_packet)

    # The FPGA's input_control unconditionally asserts control_en upon finishing ANY packet.
    # Therefore, the setpoint packet ALSO generates a 4-byte response from the FPGA.
    # We MUST read and discard this dummy response, otherwise it causes an off-by-one delay!
    dummy_resp = ser.read(4)
    if dummy_resp:
        print(f"Consumed dummy response from setpoint packet: {dummy_resp.hex()}")
    
    # Give a tiny delay for the FPGA to process the setpoint if needed
    time.sleep(0.01)

    intervals = []
    success_count = 0

    print(f"\nStarting {num_tests} tests with random data (4 decimal places)...")

    # Kp in Q16.16
    kp_q16 = int(kp_float * 65536)

    for i in range(num_tests):
        # Generate random data with 4 decimal places, which can be greater than the setpoint
        # We test both positive and negative error cases
        data_float = round(random.uniform(0.0, setpoint_float * 2.0), 4)
        data_q16 = int(data_float * 65536)
        
        data_bytes = struct.pack('<i', data_q16)
        data_packet = b'\x00' + data_bytes

        # Measure time
        start_time = time.perf_counter()
        
        # Send the packet
        ser.write(data_packet)
        
        # Wait for the 4-byte response from the FPGA
        response = ser.read(4)
        
        end_time = time.perf_counter()
        
        if len(response) == 4:
            # Result from FPGA is Q16.16 signed integer
            result_q16 = struct.unpack('<i', response)[0]
            result_float = result_q16 / 65536.0
            
            interval = end_time - start_time
            intervals.append(interval)

            # FPGA math simulation for verification:
            # error = setpoint - data
            error_q16 = setpoint_q16 - data_q16
            
            # P_prod_full = Kp * error (65-bit in FPGA, we simulate it)
            p_prod_full = kp_q16 * error_q16
            
            # saturate to 64-bit signed (Q32.32)
            MAX_64 = (1 << 63) - 1
            MIN_64 = -(1 << 63)
            if p_prod_full > MAX_64:
                p_prod_full = MAX_64
            elif p_prod_full < MIN_64:
                p_prod_full = MIN_64
                
            # Shift right by 16 bits (Q32.16)
            p_shifted = p_prod_full >> 16
            
            # Saturate to 32-bit signed Q16.16
            MAX_32 = (1 << 31) - 1
            MIN_32 = -(1 << 31)
            if p_shifted > MAX_32:
                expected_q16 = MAX_32
            elif p_shifted < MIN_32:
                expected_q16 = MIN_32
            else:
                expected_q16 = p_shifted
                
            expected_float = expected_q16 / 65536.0

            if result_q16 == expected_q16:
                success_count += 1
            else:
                print(f"Test {i+1} FAILED! Data: {data_float:.4f}, Expected: {expected_float:.4f} (Q16: {expected_q16}), Got: {result_float:.4f} (Q16: {result_q16})")
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

KP=5.5
TEST_COUNTS=(10 100 1000 10000)

echo "Running fixed-point tests to generate data for docs/testing/fixed_point_performance_tests.md..."
echo "Note: You may be prompted for sudo password if your user isn't in the dialout group."
echo ""

for COUNT in "${TEST_COUNTS[@]}"; do
    echo "=========================================="
    echo "Running for $COUNT tests..."
    sudo python3 software/test_fixed_interval.py $KP $COUNT > /tmp/fpga_fixed_test_${COUNT}.log

    SMALLEST=$(grep "Smallest" /tmp/fpga_fixed_test_${COUNT}.log | awk -F': ' '{print $2}' | awk '{print $1}')
    BIGGEST=$(grep "Biggest" /tmp/fpga_fixed_test_${COUNT}.log | awk -F': ' '{print $2}' | awk '{print $1}')
    MEAN=$(grep "Mean" /tmp/fpga_fixed_test_${COUNT}.log | awk -F': ' '{print $2}' | awk '{print $1}')
    MEDIAN=$(grep "Median" /tmp/fpga_fixed_test_${COUNT}.log | awk -F': ' '{print $2}' | awk '{print $1}')
    Q3=$(grep "3rd Quartile" /tmp/fpga_fixed_test_${COUNT}.log | awk -F': ' '{print $2}' | awk '{print $1}')
    SUCCESS=$(grep "Successful Tests" /tmp/fpga_fixed_test_${COUNT}.log | awk -F': ' '{print $2}')

    echo "| $COUNT | $SMALLEST | $BIGGEST | $MEAN | $MEDIAN | $Q3 | $SUCCESS |"
done

echo "=========================================="
echo "Done! You can copy the markdown table rows above into your docs/testing/fixed_point_performance_tests.md file."
```

## V2 Test (Dynamic Kp via Opcode)

In the V2 test, the proportional gain `Kp` is no longer hardcoded in the FPGA. Instead, it is configured dynamically using the new `0x02` opcode. The python script was updated to send the `setpoint` (opcode `0x01`) and the `Kp` (opcode `0x02`) sequentially before starting the random feedback data generation loop.

### Test Conditions

- **Baudrate**: 115200 bps
- **Controller Kp**: 5.5 (Sent dynamically via opcode `0x02`)
- **Setpoint Value**: 500.0000 (Sent dynamically via opcode `0x01`)
- **Data Range**: Random floats in [0.0000, 1000.0000] (testing both positive and negative errors)
- **Precision Limit**: 4 decimal places

### Results

| Number of Tests | Smallest Time (s) | Biggest Time (s) | Mean Time (s) | Median Time (s) | 3rd Quartile (s) | Successful Tests |
|-----------------|-------------------|------------------|---------------|-----------------|------------------|------------------|
| 10              | 0.001811          | 0.001958         | 0.001857      | 0.001834        | 0.001888         | 10 / 10          |
| 100             | 0.001804          | 0.002059         | 0.001905      | 0.001902        | 0.001945         | 100 / 100        |
| 1000            | 0.001781          | 0.002874         | 0.001912      | 0.001903        | 0.001949         | 1000 / 1000      |
| 10000           | 0.001774          | 0.004575         | 0.001911      | 0.001897        | 0.001946         | 10000 / 10000    |

### Code

*(The updated `test_fixed_interval.py` script used for this test is included below)*

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
            kp_float = float(sys.argv[1])
        else:
            kp_float = float(input("Enter proportional gain (Kp) [e.g. 5.5]: "))
            
        if len(sys.argv) > 2:
            num_tests = int(sys.argv[2])
        else:
            num_tests = 100
    except ValueError:
        print("Invalid input. Please enter a number.")
        sys.exit(1)

    try:
        ser = serial.Serial(port, baudrate, timeout=2.0)
    except Exception as e:
        print(f"Error opening serial port: {e}")
        sys.exit(1)

    print(f"Opened {port} at {baudrate} baud.")

    # 1. Send Setpoint Data (Opcode 0x01)
    # The setpoint is sent as a Q16.16 signed integer
    setpoint_float = 500.0000
    setpoint_q16 = int(setpoint_float * 65536)
    
    setpoint_bytes = struct.pack('<i', setpoint_q16)
    setpoint_packet = b'' + setpoint_bytes
    print(f"Sending setpoint: {setpoint_float:.4f} (packet: {setpoint_packet.hex()})")
    ser.write(setpoint_packet)

    # Wait a tiny bit for the FPGA to process the setpoint
    time.sleep(0.01)

    # 2. Send Kp Data (Opcode 0x02)
    # Kp in Q16.16
    kp_q16 = int(kp_float * 65536)
    kp_bytes = struct.pack('<i', kp_q16)
    kp_packet = b'' + kp_bytes
    print(f"Sending Kp: {kp_float:.4f} (packet: {kp_packet.hex()})")
    ser.write(kp_packet)
    
    # Wait a tiny bit for the FPGA to process Kp
    time.sleep(0.01)

    intervals = []
    success_count = 0

    print(f"\nStarting {num_tests} tests with random data (4 decimal places)...")

    for i in range(num_tests):
        # Generate random data with 4 decimal places, which can be greater than the setpoint
        # We test both positive and negative error cases
        data_float = round(random.uniform(0.0, setpoint_float * 2.0), 4)
        data_q16 = int(data_float * 65536)
        
        data_bytes = struct.pack('<i', data_q16)
        data_packet = b' ' + data_bytes

        # Measure time
        start_time = time.perf_counter()
        
        # Send the packet
        ser.write(data_packet)
        
        # Wait for the 4-byte response from the FPGA
        response = ser.read(4)
        
        end_time = time.perf_counter()
        
        if len(response) == 4:
            # Result from FPGA is Q16.16 signed integer
            result_q16 = struct.unpack('<i', response)[0]
            result_float = result_q16 / 65536.0
            
            interval = end_time - start_time
            intervals.append(interval)

            # FPGA math simulation for verification:
            # error = setpoint - feedback
            error_q16 = setpoint_q16 - data_q16
            
            # P_prod_full = Kp * error (65-bit in FPGA, we simulate it)
            p_prod_full = kp_q16 * error_q16
            
            # saturate to 64-bit signed (Q32.32)
            MAX_64 = (1 << 63) - 1
            MIN_64 = -(1 << 63)
            if p_prod_full > MAX_64:
                p_prod_full = MAX_64
            elif p_prod_full < MIN_64:
                p_prod_full = MIN_64
                
            # Shift right by 16 bits (Q32.16)
            p_shifted = p_prod_full >> 16
            
            # Saturate to 32-bit signed Q16.16
            MAX_32 = (1 << 31) - 1
            MIN_32 = -(1 << 31)
            if p_shifted > MAX_32:
                expected_q16 = MAX_32
            elif p_shifted < MIN_32:
                expected_q16 = MIN_32
            else:
                expected_q16 = p_shifted
                
            expected_float = expected_q16 / 65536.0

            if result_q16 == expected_q16:
                success_count += 1
            else:
                print(f"Test {i+1} FAILED! Data: {data_float:.4f}, Expected: {expected_float:.4f} (Q16: {expected_q16}), Got: {result_float:.4f} (Q16: {result_q16})")
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
    
    # Calculate 3rd quartile (75th percentile)
    sorted_intervals = sorted(intervals)
    q3_index = int(len(sorted_intervals) * 0.75)
    q3_val = sorted_intervals[q3_index]

    print("\n--- Time Interval Analysis (Seconds) ---")
    print(f"Smallest     : {smallest:.6f} s")
    print(f"Biggest      : {biggest:.6f} s")
    print(f"Mean         : {mean_val:.6f} s")
    print(f"Median       : {median_val:.6f} s")
    print(f"3rd Quartile : {q3_val:.6f} s")

if __name__ == '__main__':
    main()
```

