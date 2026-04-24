# FPGA Sobel Edge Detection

## Overview
This project implements a high-performance hardware for the **Sobel Edge Detection** algorithm on an FPGA. The system is designed to process grayscale images by calculating the magnitude of gradients ($G_x$ and $G_y$). 

The project was developed in VHDL and targeted for the **Xilinx Zynq-7000 (Arty Z7)** platform.

---

## 1. Digit-by-Digit Square Root Algorithm
The core of the magnitude calculation $\sqrt{G_x^2 + G_y^2}$ is a custom Square Root module based on the **digit-by-digit** (non-restoring) algorithm. 

### Algorithm Logic
The algorithm finds the root $Q$ of a radicand $X$ iteratively. For each step, it determines the next bit $b$ such that $(P + b)^2 \leq X$, where $P$ is the root found in previous iterations. In hardware, this is implemented using:
* **Bit-shifting** instead of multiplication to reduce resource consumption.
* **Subtractor units** to evaluate the remainder at each stage.

---

## 2. Hardware Architectures: Sequential vs. Pipelined
Two distinct architectures were implemented to evaluate performance vs. area trade-offs:

### Sequential Architecture
* **Logic:** Uses a single calculation unit controlled by a Finite State Machine (FSM). 
* **Pros:** Minimal resource usage (low Slice/LUT count).
* **Cons:** High latency; requires multiple clock cycles per pixel.

### Pipelined Architecture
* **Logic:** Breaks the algorithm into stages separated by registers.
* **Pros:** High throughput (one pixel per clock cycle after initial latency).
* **Cons:** Higher resource consumption due to pipeline registers.

### Comparative Analysis
| Feature | Sequential Architecture | Pipelined Architecture |
| :--- | :---: | :---: |
| **Throughput** | 1 result every N cycles | 1 result every cycle |
| **Latency** | N clock cycles | N clock cycles |
| **Area (LUT/FF)** | Low | High |
| **Max Frequency** | Moderate | High (Short critical paths) |

---

## 3. Sobel Operator Implementation
The Sobel filter computes the image gradient using two 3x3 kernels.

![Sobel Kernel Diagram](docs/sobel_kernel.png) ### Line Buffer & Sliding Window
To avoid re-reading pixels from memory, a **Line Buffer (FIFO)** architecture was implemented:
1. **FIFO Buffers:** Store two full rows of the image.
2. **Sliding Window:** A 3x3 register matrix extracts the neighborhood of the current pixel.
3. **Parallel Computation:** $G_x$ and $G_y$ are calculated simultaneously using dedicated adders and shifters (avoiding multipliers where possible).

---

## 4. Communication & Handshake (UART)
Data is transmitted to the PC via a UART interface at **115200 baud**. 

### Handshake Protocol
To synchronize the high-speed FPGA clock (125 MHz) with the relatively slow UART, a strict **Handshake Protocol** was used:
1. **WAIT_BUSY_HIGH:** FSM waits for the UART module to acknowledge the command and raise the `busy` signal.
2. **WAIT_BUSY_LOW:** FSM pauses until the UART finishes serializing the byte and lowers the `busy` signal.

---

## 5. System Architecture
The following block diagram illustrates the integration of the RAM, Processing Pipeline, and UART Controller.

![System Block Diagram](docs/block_diagram.png) ### State Machine Design
The Top-Level FSM manages the entire data flow:
* **IDLE:** Waiting for start signal.
* **READ_RAM:** Fetching pixel data.
* **PROCESS:** Sobel filtering and Magnitude calculation.
* **SEND_UART:** Serial transmission of results.

---

## 6. How to Run
1. **Simulation:** Use the provided testbench in Vivado to verify the `math_pkg` and `image_gradient` modules.
2. **Synthesis:** Open the Vivado project, target the Arty Z7 board, and run Synthesis/Implementation.
3. **Deployment:** Program the FPGA and use a serial terminal (e.g., Tera Term or a Python script) to receive the edge-detected image data.

## License
This project is for educational purposes as part of the VLSI Systems Design course at the University of Belgrade.
