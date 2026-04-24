# FPGA Sobel Edge Detection

## Overview
This project implements a high-performance hardware for the **Sobel Edge Detection** algorithm on an FPGA. The system is designed to process grayscale images by calculating the magnitude of gradients ($G_x$ and $G_y$). 

The project was developed in VHDL and targeted for the **Xilinx Zynq-7000 (Arty Z7)** platform.

To understand how project this project works, in the following sections, I will break down the hardware and it's logic into its core functional blocks: from how it's efficiently store and access pixels, through the mathematics behind the gradient calculation, to the final synchronization with external devices.

---

## 1. Digit-by-Digit Square Root Algorithm

To understand the hardware implementation it is best to first start with sqrt module and math behind it. Since there isn't sqrt function in standard ieee library that i used in this project, i made my own sqrt module using **Digit-by-digit calculation techinque** for binary system, wikipedia page about alogorithm [link](https://en.wikipedia.org/wiki/Square_root_algorithms#Digit-by-digit_calculation). 

I won't get in details about algorithm since it is very good explaind on wikipedia.

---

## 2. Sqrt Module

The sqrt module is resposible for implementing previos explaind algorithm and to send result to next instance. General module block diagram is:

![Block diagram of sqrt module](https://github.com/AAleksa04/FPGA-Sobel-Edge-Detector/blob/main/docs/block_sqrt.png)
 
This modul has two distinct architectures to show difrence in performance vs. area trade-offs:

### Sequential Architecture

The sqrt_seq architecture is implemented as a synchronous sequential circuit. It uses a **Finite State Machine** (FSM). It's Moore diagram look like:

![State machine sqrt_seq](https://github.com/AAleksa04/FPGA-Sobel-Edge-Detector/blob/main/docs/state_machine_sqrt.png)


### Pipelined Architecture
Pipelined architecture is designed as one big conveyer that carry all data from registars from previos architecture one by one on clk signal. It's block digram looks like this:

![Blokc diagram sqrt_pipelined](https://github.com/AAleksa04/FPGA-Sobel-Edge-Detector/blob/main/docs/block_schematic_sqrt_pipelined.png)

### Comparative Analysis

Table below show us difference between seq and pipeline architecture. I chose for primary architecture of sqrt module to be pipelined as it gives constantly one output pixel every clock cycle wich mantains a continuous data flow from memory to the output.

![Table](https://github.com/AAleksa04/FPGA-Sobel-Edge-Detector/blob/main/docs/tabel.png)

---

## 3. Sobel Operator Implementation

The Sobel operator is a 2D spatial filter used for edge detection. It approximates the image gradient (rate of change in pixel intensity) in two directions horizontal and vertical and combines them into a single gradient magnitude that highlights edges.

Let's start whit image that is procesed.

My sobel is made only for images 256x256 8 bit greyscale images. Image that sobel is operating on is stored in initialized BRAM (`im_ram.vhd`), initialized from `cameraman.dat`. 

`im_ram.vhd` is configured as **Simple Dual Port**, one port for reading pixels, one for writing the results back.



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
