# MIPS-Microprocessor-Pipelined
RTL Design of a 5 stage Pipelined MIPS RISC microprocessor without Hazard handling
---
Below is an updated draft of the GitHub README file that emphasizes the simulation results and explains that the design has no hazard detection/handling – instead, it uses strategic NOP insertions to make the test cases work correctly.

-----------------------------------------------------------
## 5‑Stage Pipelined MIPS RISC Microprocessor (Verilog Implementation)
This project implements a classic MIPS processor using a 5‑stage pipeline (IF, ID, EX, MEM, WB) without any built‑in hazard detection or forwarding. To ensure correct operation, the testbench carefully inserts NOP (No Operation) instructions between dependent instructions, preventing data hazards for the specific test cases demonstrated.

-----------------------------------------------------------
## Table of Contents

- [Overview](#overview)
- [Design Highlights](#design-highlights)
- [Testbench & Simulation](#testbench--simulation)
- [Simulation Results](#simulation-results)
- [Future Work](#future-work)
- [License](#license)

-----------------------------------------------------------
## Overview

This repository contains the Verilog source for a pipelined MIPS processor. The design supports R‑, I‑, and J‑type instructions but does not include any hazard detection or data forwarding mechanisms. Instead, our simulation and testbench employ strategic insertion of NOP instructions to “stall” the pipeline and allow the write‑back phase to complete before a dependent instruction is fetched.

-----------------------------------------------------------
## Design Highlights

- **5‑Stage Pipeline Architecture:**  
  Divided into Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory Access (MEM), and Write‑Back (WB) stages. Each stage passes data and control signals to the next via dedicated registers.

- **No Hazard Handling:**  
  The processor intentionally omits hazard detection and forwarding logic. This means that if instructions with data dependencies are issued back-to-back, they can produce incorrect results. Instead, separate instruction sequences are constructed with NOP instructions between critical operations to manually avoid hazards.

- **Modular Design:**  
  The design includes an ALU and an ALU control module, sign/zero extension modules, multiplexers, and memory blocks (instruction memory, data memory, and a register file).

-----------------------------------------------------------
## Testbench & Simulation

The testbench initializes the processor by:

-  Setting the instruction memory with a sequence of instructions interleaved with NOPs.  
-  Initializing registers and data memory to zero.  
-  Applying reset for a defined period before releasing it.  
-  Running the simulation for enough time to allow the pipeline to flush all instructions.

### Why NOPs?
Since our design does not implement hazard detection, instructions that depend on the results of previous operations are separated by NOPs. For example:
- A dependency exists between the `addi $s0, $0, 5` and the subsequent use of `$s0` in `andi $s2, $s0, 0xF`.  
- Inserting two or three NOPs allows the write‑back stage to complete before the next instruction that uses the computed value is issued.

### Simulation Commands

Compile with Icarus Verilog:
  $ iverilog -g2012 -o mips_sim mips.v tb.v

Run the simulation:
  $ vvp mips_sim

View resulting waveforms (optional):
  $ gtkwave waves.vcd

-----------------------------------------------------------
## Simulation Results

The simulation output confirms proper pipelined operation. Despite the absence of hardware hazard handling, proper results were obtained by ensuring that NOPs separated dependent instructions. Some key results from the simulation:

- **Register Outputs:**
  - **$s0 (reg16):** 5 (computed using `addi $s0, $zero, 5`)
  - **$s1 (reg17):** 10 (computed using `addi $s1, $zero, 10`)
  - **$t0 (reg8):** 15 (result of `add $t0, $s1, $s0`)
  - **$s2 (reg18):** 5 (result of `andi $s2, $s0, 0xF`)
  - **$s3 (reg19):** 0xFA (result of `ori $s3, $s1, 0xF0`)
  - **$s4 (reg20):** 0 (result of `slti $s4, $s1, 10`)
  - **$t1 (reg9):** 15 (loaded via `lw $t1, 16($zero)`)
  - **$s6 (reg22):** 0xFF (computed using `addi $s6, $zero, 0xFF`)

- **Memory Output:**
  - **Data Memory Location (Mem):** 15  
    The store instruction (`sw $t0, 16($zero)`) writes 15 into memory at address 16 (index 4 for words).

- **Waveform Observations:**
  - The PC increments in steps of 4 bytes as expected.
  - Instructions (including the NOPs, displayed as `00000000`) are fetched in proper order with clear delays that allow results to propagate.
  - The final register and memory states match once all instructions have flushed through the pipeline.

These results verify that our processor processes a carefully constructed instruction sequence correctly—even without hardware hazard resolution—by relying on time delays (NOPs) to prevent overlapping of dependent operations.

-----------------------------------------------------------
## License

This project is released under the MIT License.

-----------------------------------------------------------
*This design highlights the classic challenges of pipelined processor architecture. While it functions correctly for our test cases (with NOPs handling data hazards externally), it is an excellent educational tool for exploring both the pipelining concept and the complexities that come with implementing hazard resolution in hardware.*
