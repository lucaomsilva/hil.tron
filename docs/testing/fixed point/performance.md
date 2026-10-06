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
KI=3.4
TEST_COUNTS=(10 100 1000 10000)

echo "Running fixed-point tests to generate data for docs/testing/fixed_point_performance_tests.md..."
echo "Note: You may be prompted for sudo password if your user isn't in the dialout group."
echo ""

for COUNT in "${TEST_COUNTS[@]}"; do
    echo "=========================================="
    echo "Running for $COUNT tests..."
    sudo python3 software/test_fixed_interval.py $KP $KI $COUNT > /tmp/fpga_fixed_test_${COUNT}.log

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

## V2 Test (Dynamic Kp and Ki via Opcode)

In the V2 test, both the proportional gain `Kp` and integral gain `Ki` are configured dynamically using opcodes `0x02` and `0x03` respectively. The python script was updated to sequentially send the setpoint and the two gains before starting the feedback loop.

### Test Conditions

- **Baudrate**: 115200 bps
- **Controller Kp**: 5.5 (Sent dynamically via opcode `0x02`)
- **Controller Ki**: 3.4 (Sent dynamically via opcode `0x03`)
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

*(Note: Re-run the bash script below to update these results for the PI controller)*

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
    port = '/dev/ttyUSB1'
    baudrate = 115200
    
    try:
        kp_float = float(sys.argv[1]) if len(sys.argv) > 1 else float(input("Enter proportional gain (Kp) [e.g. 5.5]: "))
        ki_float = float(sys.argv[2]) if len(sys.argv) > 2 else float(input("Enter integral gain (Ki) [e.g. 3.4]: "))
        num_tests = int(sys.argv[3]) if len(sys.argv) > 3 else 100
    except ValueError:
        print("Invalid input.")
        sys.exit(1)

    try:
        ser = serial.Serial(port, baudrate, timeout=2.0)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

    print(f"Opened {port} at {baudrate} baud.")

    setpoint_float = 500.0000
    setpoint_q16 = int(setpoint_float * 65536)
    
    # 1. Send Setpoint
    ser.write(b'\x01' + struct.pack('<i', setpoint_q16))
    time.sleep(0.01)

    # 2. Send Kp
    kp_q16 = int(kp_float * 65536)
    ser.write(b'\x02' + struct.pack('<i', kp_q16))
    time.sleep(0.01)
    
    # 3. Send Ki
    ki_q16 = int(ki_float * 65536)
    ser.write(b'\x03' + struct.pack('<i', ki_q16))
    time.sleep(0.01)

    intervals = []
    success_count = 0
    
    accumulator_q48 = 0

    print(f"\nStarting {num_tests} PI tests...")

    for i in range(num_tests):
        data_float = round(random.uniform(0.0, setpoint_float * 2.0), 4)
        data_q16 = int(data_float * 65536)
        
        start_time = time.perf_counter()
        ser.write(b'\x00' + struct.pack('<i', data_q16))
        response = ser.read(4)
        end_time = time.perf_counter()
        
        if len(response) == 4:
            result_q16 = struct.unpack('<i', response)[0]
            result_float = result_q16 / 65536.0
            intervals.append(end_time - start_time)

            # FPGA math simulation:
            error_q16 = setpoint_q16 - data_q16
            
            # P Term
            p_prod_full = kp_q16 * error_q16
            p_shifted = p_prod_full >> 16
            
            # I Term
            i_prod_full = ki_q16 * error_q16
            i_shifted = i_prod_full >> 16
            accumulator_q48 += i_shifted
            
            # Anti-windup
            MAX_48 = (1 << 47) - 1
            MIN_48 = -(1 << 47)
            if accumulator_q48 > MAX_48: accumulator_q48 = MAX_48
            elif accumulator_q48 < MIN_48: accumulator_q48 = MIN_48
            
            # PI Sum
            pi_sum_full = p_shifted + accumulator_q48
            
            MAX_32 = (1 << 31) - 1
            MIN_32 = -(1 << 31)
            if pi_sum_full > MAX_32: expected_q16 = MAX_32
            elif pi_sum_full < MIN_32: expected_q16 = MIN_32
            else: expected_q16 = pi_sum_full
                
            if result_q16 == expected_q16:
                success_count += 1
            else:
                print(f"Test {i+1} FAILED! Data: {data_float:.4f}, Expected Q16: {expected_q16}, Got Q16: {result_q16}")
        else:
            print(f"Test {i+1} FAILED to receive full response.")

    ser.close()

    if not intervals: return
    
    print("\n--- Test Verification ---")
    print(f"Successful Tests: {success_count} / {num_tests}")
    
    smallest = min(intervals)
    biggest = max(intervals)
    mean_val = statistics.mean(intervals)
    median_val = statistics.median(intervals)
    
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

To run, you can execute this bash script in root path of project:
```bash
#!/bin/bash

# This script runs the python test script for 10, 100, 1000, and 10000 iterations.
# It captures the results and formats them so you can easily copy-paste them into your markdown file.

KP=5.5
KI=3.4
TEST_COUNTS=(10 100 1000 10000)

echo "Running fixed-point tests to generate data for docs/testing/fixed_point_performance_tests.md..."
echo "Note: You may be prompted for sudo password if your user isn't in the dialout group."
echo ""

for COUNT in "${TEST_COUNTS[@]}"; do
    echo "=========================================="
    echo "Running for $COUNT tests..."
    sudo python3 software/test_fixed_interval.py $KP $KI $COUNT > /tmp/fpga_fixed_test_${COUNT}.log

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

## V3 Test (Dynamic Kp, Ki, and Kd via Opcode)

In the V3 test, the Proportional (Kp), Integral (Ki), and Derivative (Kd) gains are configured dynamically using opcodes `0x02`, `0x03`, and `0x04` respectively. The python script was updated to sequentially send the setpoint and the three gains before starting the feedback loop.

### Test Conditions

- **Baudrate**: 115200 bps
- **Controller Kp**: 5.5 (Sent dynamically via opcode `0x02`)
- **Controller Ki**: 3.4 (Sent dynamically via opcode `0x03`)
- **Controller Kd**: 1.2 (Sent dynamically via opcode `0x04`)
- **Setpoint Value**: 500.0000 (Sent dynamically via opcode `0x01`)
- **Data Range**: Random floats in [0.0000, 1000.0000]

### Results

| Number of Tests | Smallest Time (s) | Biggest Time (s) | Mean Time (s) | Median Time (s) | 3rd Quartile (s) | Successful Tests |
|-----------------|-------------------|------------------|---------------|-----------------|------------------|------------------|
| 10              | 0.001812          | 0.001902         | 0.001862      | 0.001861        | 0.001878         | 10 / 10          |
| 100             | 0.001797          | 0.002064         | 0.001903      | 0.001898        | 0.001941         | 100 / 100        |
| 1000            | 0.001788          | 0.002748         | 0.001899      | 0.001886        | 0.001925         | 1000 / 1000      |
| 10000           | 0.001776          | 0.005561         | 0.001896      | 0.001884        | 0.001923         | 10000 / 10000    |

### Code

*(The updated script used for this test is included below)*

```python
import serial
import time
import struct
import sys
import random
import statistics

def main():
    port = '/dev/ttyUSB1'
    baudrate = 115200
    
    try:
        kp_float = float(sys.argv[1]) if len(sys.argv) > 1 else float(input("Enter proportional gain (Kp) [e.g. 5.5]: "))
        ki_float = float(sys.argv[2]) if len(sys.argv) > 2 else float(input("Enter integral gain (Ki) [e.g. 3.4]: "))
        kd_float = float(sys.argv[3]) if len(sys.argv) > 3 else float(input("Enter derivative gain (Kd) [e.g. 1.2]: "))
        num_tests = int(sys.argv[4]) if len(sys.argv) > 4 else 100
    except ValueError:
        print("Invalid input.")
        sys.exit(1)

    try:
        ser = serial.Serial(port, baudrate, timeout=2.0)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

    print(f"Opened {port}")

    setpoint_float = 500.0000
    setpoint_q16 = int(setpoint_float * 65536)
    
    # 1. Send Setpoint
    ser.write(b'\x01' + struct.pack('<i', setpoint_q16))
    time.sleep(0.01)

    # 2. Send Kp
    kp_q16 = int(kp_float * 65536)
    ser.write(b'\x02' + struct.pack('<i', kp_q16))
    time.sleep(0.01)
    
    # 3. Send Ki
    ki_q16 = int(ki_float * 65536)
    ser.write(b'\x03' + struct.pack('<i', ki_q16))
    time.sleep(0.01)

    # 4. Send Kd
    kd_q16 = int(kd_float * 65536)
    ser.write(b'\x04' + struct.pack('<i', kd_q16))
    time.sleep(0.01)

    intervals = []
    success_count = 0
    
    prev_feedback_q16 = 0
    accumulator_q48 = 0

    print(f"\nStarting {num_tests} PID tests...")

    for i in range(num_tests):
        data_float = round(random.uniform(0.0, setpoint_float * 2.0), 4)
        data_q16 = int(data_float * 65536)
        
        start_time = time.perf_counter()
        ser.write(b'\x00' + struct.pack('<i', data_q16))
        response = ser.read(4)
        end_time = time.perf_counter()
        
        if len(response) == 4:
            result_q16 = struct.unpack('<i', response)[0]
            result_float = result_q16 / 65536.0
            intervals.append(end_time - start_time)

            # FPGA math simulation:
            error_q16 = setpoint_q16 - data_q16
            
            # P Term
            p_prod_full = kp_q16 * error_q16
            p_shifted = p_prod_full >> 16
            
            # I Term
            i_prod_full = ki_q16 * error_q16
            i_shifted = i_prod_full >> 16
            accumulator_q48 += i_shifted
            
            # Anti-windup
            MAX_48 = (1 << 47) - 1
            MIN_48 = -(1 << 47)
            if accumulator_q48 > MAX_48: accumulator_q48 = MAX_48
            elif accumulator_q48 < MIN_48: accumulator_q48 = MIN_48
            
            # D Term (Derivative on Measurement)
            feedback_diff_q16 = prev_feedback_q16 - data_q16
            d_prod_full = kd_q16 * feedback_diff_q16
            d_shifted = d_prod_full >> 16
            prev_feedback_q16 = data_q16
            
            # PID Sum
            pid_sum_full = p_shifted + accumulator_q48 + d_shifted
            
            MAX_32 = (1 << 31) - 1
            MIN_32 = -(1 << 31)
            if pid_sum_full > MAX_32: expected_q16 = MAX_32
            elif pid_sum_full < MIN_32: expected_q16 = MIN_32
            else: expected_q16 = pid_sum_full
                
            if result_q16 == expected_q16:
                success_count += 1
            else:
                print(f"Test {i+1} FAILED! Data: {data_float:.4f}, Expected Q16: {expected_q16}, Got Q16: {result_q16}")
        else:
            print(f"Test {i+1} FAILED to receive full response.")

    ser.close()

    if not intervals: return
    
    print("\n--- Test Verification ---")
    print(f"Successful Tests: {success_count} / {num_tests}")
    
    smallest = min(intervals)
    biggest = max(intervals)
    mean_val = statistics.mean(intervals)
    median_val = statistics.median(intervals)
    
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

To run, you can execute this bash script in root path of project:
```bash
#!/bin/bash

# This script runs the python test script for 10, 100, 1000, and 10000 iterations.
# It captures the results and formats them so you can easily copy-paste them into your markdown file.

KP=5.5
KI=3.4
KD=1.2
TEST_COUNTS=(10 100 1000 10000)

echo "Running fixed-point tests to generate data for docs/testing/fixed_point_performance_tests.md..."
echo "Note: You may be prompted for sudo password if your user isn't in the dialout group."
echo ""

for COUNT in "${TEST_COUNTS[@]}"; do
    echo "=========================================="
    echo "Running for $COUNT tests..."
    sudo python3 software/test_fixed_interval.py $KP $KI $KD $COUNT > /tmp/fpga_fixed_test_${COUNT}.log

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
