# Derivative (D) Control Comparison

This document compares the Hardware-in-the-Loop (HIL) plant simulation results with and without the FPGA-based pure derivative controller. The simulation is driven by the [HIL Simulation Script](#hil-simulation-script).

## Plant Transfer Function

The plant is modeled as a continuous first-order system with the following parameters:
- **Plant Proportional Gain ($K_{plant}$)**: 1.0
- **Time Constant ($\tau$)**: 1.0 second

The continuous transfer function $G(s)$ is:
$$G(s) = \frac{K_{plant}}{\tau s + 1} = \frac{1}{s + 1}$$

### Open-Loop Characteristics (Without Control)
- **Pole**: $s = -1$ (Stable, left-half plane)
- **Cutoff Frequency ($\omega_c$)**: $1/\tau = 1$ rad/s
- **Rise Time (10% to 90%)**: $\approx 2.2\tau = 2.2$ seconds
- **Settling Time (2% band)**: $\approx 4\tau = 4.0$ seconds

In the open-loop test, a step input (setpoint) is applied directly to the plant. Because the plant gain is 1.0, the steady-state output will eventually reach the input value. 

![Without Control](img/hil_without_control_ss.png)

*(Note: In the plot above, the open-loop response exponentially approaches the setpoint, taking roughly 4.0 seconds to settle.)*

---

## Closed-Loop System (With Pure Derivative Control)

For the closed-loop HIL simulation, the FPGA computes the control effort $u(t)$ based on the error between the setpoint and the plant output. However, to avoid "derivative kick," the derivative action in this controller is calculated based solely on the measurement (feedback) instead of the error.

### Controller Parameters
- **Setpoint**: $500.0$
- **Controller Proportional Gain ($K_p$)**: $0.0$
- **Controller Integral Gain ($K_i$)**: $0.0$
- **Controller Derivative Gain ($K_d$)**: $1.2$

With only the derivative controller acting on the process variable $Y(s)$, the control effort is $U(s) = -K_d s Y(s)$. 
Substituting this into the plant equation $Y(s) = G(s)U(s)$ for the closed-loop response to a setpoint yields:
$Y(s) = \frac{1}{s+1} (-K_d s Y(s))$, which simplifies to $Y(s) \left( 1 + \frac{K_d s}{s+1} \right) = 0$.

Because there is no proportional or integral term acting on the error, the controller fundamentally ignores the setpoint.

### Closed-Loop Characteristics
- **Expected Steady-State Output**: $0$
- **System Dynamics**: The pure derivative controller strictly opposes changes in the process variable. Since the setpoint does not induce any control effort, the plant output will remain at 0 (or rapidly return to 0 if disturbed).

![With Control](img/hil_with_control_ss.png)

### Analysis of the Results

1. **Setpoint Tracking**: Because $K_p = 0$ and $K_i = 0$, the controller generates zero effort in response to the setpoint change. 
2. **Derivative Action on PV**: The derivative action is designed to brake the system by opposing the rate of change of the process variable. Without a proportional term to drive the system forward, the derivative term simply acts as additional damping, keeping the plant output at exactly 0.
3. **Control Effort ($u$)**: The control effort remains at 0 throughout the simulation because the process variable never moves, hence its derivative is always zero.

---

## Dependencies

To run this simulation, you will need to install the required Python libraries (`pyserial`, `numpy`, `matplotlib`, and `control`). Run the following commands in the same folder of [HIL Simulation Script](#hil-simulation-script) to create a Python virtual environment and install the dependencies:

```bash
python3 -m venv venv
sudo venv/bin/python3 -m pip install pyserial numpy matplotlib control
```

## V2 HIL Simulation Script (Difference Equations)

The simulation script used to generate these results is provided below. This script defines the continuous plant, converts it to discrete difference equations, configures the FPGA over UART using the new opcodes, runs the Hardware-in-the-Loop test, and plots the results.

```python
import serial
import time
import struct
import sys
import numpy as np
import matplotlib.pyplot as plt
import control as ct
print("python-control", ct.__version__)

def main():
    # 1. Setup Serial Port
    port = '/dev/ttyUSB1'
    baudrate = 115200
 
    try:
        ser = serial.Serial(port, baudrate, timeout=2.0)
        print(f"Opened {port} at {baudrate} baud.")
    except Exception as e:
        print(f"Error opening serial port: {e}")
        sys.exit(1)

    # 2. Define the Plant using Python Control Library
    # Let's create a simple first-order system
    # G(s) = K / (tau * s + 1)
    K_plant = 1.0
    tau = 1.0
    sys_c = ct.tf([K_plant], [tau, 1])
    print(f"\nContinuous Plant Transfer Function:\n{sys_c}")

    # Convert to Discrete difference equations
    dt = 0.01 # 10 ms sample time
    sys_d = ct.sample_system(sys_c, dt, method='zoh')

    b = sys_d.num[0][0]
    a = sys_d.den[0][0]
    
    # Pad numerator with leading zeros to match denominator length
    # This ensures b aligns with the correct delays (e.g. u[k-1])
    if len(b) < len(a):
        b = np.pad(b, (len(a) - len(b), 0), 'constant')
    
    # Normalize by leading denominator coefficient
    b = b / a[0]
    a = a / a[0]

    # 3. Setup HIL Simulation Parameters
    setpoint_float = 500.0
    setpoint_q16 = int(setpoint_float * 65536)

    # Send Setpoint Packet (Opcode 0x01)
    setpoint_bytes = struct.pack('<i', setpoint_q16)
    setpoint_packet = b'\x01' + setpoint_bytes
    print(f"Sending setpoint: {setpoint_float:.4f}")
    ser.write(setpoint_packet)

    # Give a tiny delay for the FPGA to process the setpoint
    time.sleep(0.01)

    kp_float = 0.0
    kp_q16 = int(kp_float * 65536)

    # Send Kp Packet (Opcode 0x02)
    kp_bytes = struct.pack('<i', kp_q16)
    kp_packet = b'\x02' + kp_bytes
    print(f"Sending Kp: {kp_float:.4f}")
    ser.write(kp_packet)

    # Give a tiny delay for the FPGA to process Kp
    time.sleep(0.01)

    ki_float = 0.0
    ki_q16 = int(ki_float * 65536)

    # Send Ki Packet (Opcode 0x03)
    ki_bytes = struct.pack('<i', ki_q16)
    ki_packet = b'\x03' + ki_bytes
    print(f"Sending Ki: {ki_float:.4f}")
    ser.write(ki_packet)

    # Give a tiny delay for the FPGA to process Ki
    time.sleep(0.01)

    kd_float = 1.2
    kd_q16 = int(kd_float * 65536)

    # Send Kd Packet (Opcode 0x04)
    kd_bytes = struct.pack('<i', kd_q16)
    kd_packet = b'\x04' + kd_bytes
    print(f"Sending Kd: {kd_float:.4f}")
    ser.write(kd_packet)

    # Give a tiny delay for the FPGA to process Kd
    time.sleep(0.01)

    # 4. Run the HIL Simulation Loop
    num_steps = 200  # 200 steps * 0.01s = 2.0 seconds of simulation

    y_hist = np.zeros(len(a))
    u_hist = np.zeros(len(b))

    y_open_hist = np.zeros(len(a))
    u_open_hist = np.zeros(len(b))

    history_t = []
    history_y = []
    history_y_open = []
    history_u = []
    history_setpoint = []

    print("\nStarting Hardware-in-the-Loop Simulation...")
    start_sim_time = time.time()

    for k in range(num_steps):
        # Shift histories for difference equations
        for i in range(len(a)-1, 0, -1):
            y_hist[i] = y_hist[i-1]
            y_open_hist[i] = y_open_hist[i-1]
        for i in range(len(b)-1, 0, -1):
            u_hist[i] = u_hist[i-1]
            u_open_hist[i] = u_open_hist[i-1]

        # Calculate current output of the plant using difference equation
        y_float = 0.0
        y_open_float = 0.0
        for i in range(1, len(a)):
            if i < len(y_hist):
                y_float -= a[i] * y_hist[i]
                y_open_float -= a[i] * y_open_hist[i]
        for i in range(1, len(b)):
            if i < len(u_hist):
                y_float += b[i] * u_hist[i]
                y_open_float += b[i] * u_open_hist[i]

        y_hist[0] = y_float
        y_open_hist[0] = y_open_float

        # Quantize to Q16.16 format for the FPGA
        y_q16 = int(y_float * 65536)

        # Send current plant output (feedback) to FPGA (Opcode 0x00)
        data_packet = b'\x00' + struct.pack('<i', y_q16)
        ser.write(data_packet)

        # Wait for the control signal (u) from FPGA
        response = ser.read(4)

        if len(response) == 4:
            # Result from FPGA is Q16.16 signed integer
            u_q16 = struct.unpack('<i', response)[0]
            u_float = u_q16 / 65536.0
        else:
            print(f"Error: Step {k} failed to receive full response. Using u = 0.")
            print(f"response={response}")
            u_float = 0.0

        u_hist[0] = u_float
        u_open_hist[0] = setpoint_float

        # Record history for plotting
        t = k * dt
        history_t.append(t)
        history_y.append(y_float)
        history_u.append(u_float)
        history_setpoint.append(setpoint_float)
        history_y_open.append(y_open_float)

    ser.close()
    print(f"Simulation finished in {time.time() - start_sim_time:.2f} seconds.")

    # 5. Plot the Results
    # Graphic 1: With Control
    plt.figure(figsize=(10, 8))

    plt.subplot(2, 1, 1)
    plt.plot(history_t, history_y, label='Plant Output (Closed-Loop)', color='blue', linewidth=2)
    plt.plot(history_t, history_setpoint, label='Setpoint', color='red', linestyle='--')
    plt.title('Hardware-in-the-Loop - With Pure Derivative Control (Closed-Loop)')
    plt.ylabel('Amplitude')
    plt.grid(True)
    plt.legend()

    plt.subplot(2, 1, 2)
    plt.plot(history_t, history_u, label='Control Signal (FPGA)', color='green')
    plt.title('Controller Effort')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Control Signal (u)')
    plt.grid(True)
    plt.legend()

    plt.tight_layout()
    plt.savefig('hil_with_control.png')

    # Graphic 2: Without Control
    plt.figure(figsize=(10, 4))
    plt.plot(history_t, history_y_open, label='Plant Output (Open-Loop)', color='orange', linewidth=2)
    plt.plot(history_t, history_setpoint, label='Setpoint (Input Step)', color='red', linestyle='--')
    plt.title('Plant Simulation - Without Control (Open-Loop Step Response)')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Amplitude')
    plt.grid(True)
    plt.legend()

    plt.tight_layout()
    plt.savefig('hil_without_control.png')

    print("\nPlots saved as 'hil_with_control.png' and 'hil_without_control.png'")

if __name__ == '__main__':
    main()
```

## V2 State-Space Simulation Script

The simulation script used to generate these results is provided below. This script performs the Hardware-in-the-Loop test utilizing matrix math (State-Space).

```python
import serial
import time
import struct
import sys
import numpy as np
import matplotlib.pyplot as plt
import control as ct

def main():
    # 1. Setup Serial Port
    port = '/dev/ttyUSB1'
    baudrate = 115200
 
    try:
        ser = serial.Serial(port, baudrate, timeout=2.0)
        print(f"Opened {port} at {baudrate} baud.")
    except Exception as e:
        print(f"Error opening serial port: {e}")
        sys.exit(1)

    # 2. Define the Plant using Python Control Library
    K_plant = 1.0
    tau = 1.0
    sys_c = ct.tf([K_plant], [tau, 1])
    print(f"\nContinuous Plant Transfer Function:\n{sys_c}")

    # Convert to Discrete State-Space
    dt = 0.01 # 10 ms sample time
    sys_d = ct.sample_system(sys_c, dt, method='zoh')
    ss_d = ct.tf2ss(sys_d)

    A, B, C, D = ss_d.A, ss_d.B, ss_d.C, ss_d.D

    # 3. Setup HIL Simulation Parameters
    setpoint_float = 500.0
    setpoint_q16 = int(setpoint_float * 65536)

    # Send Setpoint Packet (Opcode 0x01)
    ser.write(b'\x01' + struct.pack('<i', setpoint_q16))
    print(f"Sending setpoint: {setpoint_float:.4f}")
    time.sleep(0.01)

    kp_float = 0.0
    kp_q16 = int(kp_float * 65536)

    # Send Kp Packet (Opcode 0x02)
    ser.write(b'\x02' + struct.pack('<i', kp_q16))
    print(f"Sending Kp: {kp_float:.4f}")
    time.sleep(0.01)

    ki_float = 0.0
    ki_q16 = int(ki_float * 65536)

    # Send Ki Packet (Opcode 0x03)
    ser.write(b'\x03' + struct.pack('<i', ki_q16))
    print(f"Sending Ki: {ki_float:.4f}")
    time.sleep(0.01)

    kd_float = 1.2
    kd_q16 = int(kd_float * 65536)

    # Send Kd Packet (Opcode 0x04)
    ser.write(b'\x04' + struct.pack('<i', kd_q16))
    print(f"Sending Kd: {kd_float:.4f}")
    time.sleep(0.01)

    # 4. Run the HIL Simulation Loop
    num_steps = 200  # 2.0 seconds of simulation

    x = np.zeros((A.shape[0], 1))
    x_open = np.zeros((A.shape[0], 1))

    history_t = []
    history_y = []
    history_y_open = []
    history_u = []
    history_setpoint = []

    print("\nStarting State-Space HIL Simulation...")
    start_sim_time = time.time()

    for k in range(num_steps):
        # Calculate current output using state-space matrices
        y_float = float((C @ x).item())
        y_open_float = float((C @ x_open).item())

        # Quantize to Q16.16 format for the FPGA
        y_q16 = int(y_float * 65536)

        # Send current plant output (feedback) to FPGA (Opcode 0x00)
        ser.write(b'\x00' + struct.pack('<i', y_q16))

        # Wait for the control signal (u) from FPGA
        response = ser.read(4)

        if len(response) == 4:
            u_q16 = struct.unpack('<i', response)[0]
            u_float = u_q16 / 65536.0
        else:
            print(f"Error: Step {k} failed to receive full response. Using u = 0.")
            u_float = 0.0

        # Update the plant states
        x = A @ x + B * u_float
        x_open = A @ x_open + B * setpoint_float

        # Record history for plotting
        t = k * dt
        history_t.append(t)
        history_y.append(y_float)
        history_u.append(u_float)
        history_setpoint.append(setpoint_float)
        history_y_open.append(y_open_float)

    ser.close()
    print(f"Simulation finished in {time.time() - start_sim_time:.2f} seconds.")

    # 5. Plot the Results
    plt.figure(figsize=(10, 8))

    plt.subplot(2, 1, 1)
    plt.plot(history_t, history_y, label='Plant Output (Closed-Loop)', color='blue', linewidth=2)
    plt.plot(history_t, history_setpoint, label='Setpoint', color='red', linestyle='--')
    plt.title('State-Space HIL - With Pure Derivative Control (Closed-Loop)')
    plt.ylabel('Amplitude')
    plt.grid(True)
    plt.legend()

    plt.subplot(2, 1, 2)
    plt.plot(history_t, history_u, label='Control Signal (FPGA)', color='green')
    plt.title('Controller Effort')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Control Signal (u)')
    plt.grid(True)
    plt.legend()

    plt.tight_layout()
    plt.savefig('hil_with_control_ss.png')

    plt.figure(figsize=(10, 4))
    plt.plot(history_t, history_y_open, label='Plant Output (Open-Loop)', color='orange', linewidth=2)
    plt.plot(history_t, history_setpoint, label='Setpoint (Input Step)', color='red', linestyle='--')
    plt.title('State-Space Simulation - Without Control (Open-Loop)')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Amplitude')
    plt.grid(True)
    plt.legend()

    plt.tight_layout()
    plt.savefig('hil_without_control_ss.png')

    print("\nPlots saved as 'hil_with_control_ss.png' and 'hil_without_control_ss.png'")

if __name__ == '__main__':
    main()
```

### Run Script

Inside the script folder, after the dependencies have been installed, execute one of the following commands to run the simulation:

```bash
sudo venv/bin/python3 main.py
```
