# Closed-Loop DDD Pacemaker in Verilog

This project implements a Closed-Loop DDD Pacemaker using Verilog. A DDD pacemaker can sense and pace both the atrium and ventricle. The system includes an integrated physiological heart model to simulate various cardiac conditions, allowing the pacemaker's closed-loop control to adapt dynamically to the simulated patient's rhythm.

## Project Structure

The project directory is structured as follows:

```
e:\PROJECTS\VERILOG\CLOSED_LOOP_PACEMAKER
├── IMAGES\                   # Images/Diagrams related to the project (currently empty)
└── SOURCES\
    ├── DESIGN_SOURCES\       # Synthesizable RTL Verilog files
    └── SIMULATION_SOURCES\   # Testbench and simulation environment
```

### Design Sources (`SOURCES/DESIGN_SOURCES`)

The hardware implementation consists of modular blocks:

- **`pacemaker_top.v`**: The top-level entity that instantiates and connects all the modules of the system.
- **`heart_model.v`**: An emulator for the heart that generates intrinsic atrial and ventricular signals. It can simulate various physiological conditions such as Normal rhythm, Bradycardia, Tachycardia, AV Block, and AFib.
- **`pacemaker_ddd_fsm.v`**: The core finite state machine implementing the DDD logic. It tracks Atrial Escape Interval (AEI), AV Delay (AVD), and Refractory periods, making decisions to pace or inhibit pacing based on sensed events. It also handles emergency pacing.
- **`rhythm_classifier.v`**: A real-time analysis module that measures PP, RR, and AV intervals to classify the current heart rhythm (Normal, Brady, Tachy, AV Block, AFib).
- **`adaptive_av_delay.v`**: Dynamically adjusts the Atrioventricular (AV) delay based on the patient's BPM, shortening the delay at higher heart rates to optimize cardiac output.
- **`bpm_calculator.v`**: Calculates the patient's heart rate in Beats Per Minute (BPM) based on detected ventricular events.
- **`safety_monitor.v`**: A watchdog module that constantly monitors pacing signals to detect hardware faults or timing violations (e.g., simultaneous A and V pacing), asserting a fault flag if a violation occurs.

### Simulation Sources (`SOURCES/SIMULATION_SOURCES`)

- **`pacemaker_closed_loop_tb.v`**: A comprehensive closed-loop testbench. It instantiates the `pacemaker_top` and runs it through multiple scenarios by driving the `heart_mode` parameter:
  1. Normal Heart Rate
  2. Bradycardia
  3. Tachycardia
  4. AV Block
  5. Atrial Fibrillation (AFib)
  It also tests the emergency pacing override and injects a simulated fault to verify the safety monitor's response.

## Features

- **DDD Mode Pacing:** Full Atrial and Ventricular sensing and pacing capabilities.
- **Closed-Loop Simulation:** Contains a built-in physiological heart emulator to immediately test pacing reactions.
- **Adaptive AV Delay:** Dynamically shortens AV delay for faster heart rates mimicking natural AV node physiology.
- **Rhythm Classification:** Real-time diagnostics of heart conditions (Normal, Bradycardia, Tachycardia, AV block, AFib).
- **Safety Monitor:** Hardcoded safety assertions to prevent harmful pacing patterns.
- **Emergency Mode:** An emergency override to drive pacing at a safe, fixed rate (90 BPM).

## Getting Started

To simulate the project:
1. Load all Verilog files in the `SOURCES/DESIGN_SOURCES` directory into your preferred Verilog simulator (e.g., ModelSim, Vivado, Verilator).
2. Set `pacemaker_closed_loop_tb.v` as the top module for simulation.
3. Run the simulation. The testbench is self-checking and will print out the dynamic reactions of the pacemaker (sensing, pacing, rhythm classification changes, and safety faults) to the console.
