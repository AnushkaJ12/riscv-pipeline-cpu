# RISC-V 5-Stage Pipelined CPU

A 32-bit RISC-V processor implemented in Verilog from scratch.

## Features
- 5-stage pipeline: IF → ID → EX → MEM → WB
- Supports R-type, I-type, Load, Store, Branch instructions
- Forwarding unit to resolve data hazards
- Hazard detection unit with stall insertion for load-use hazards
- Branch resolution with pipeline flush
- Verified with testbenches using Icarus Verilog + GTKWave

## Project Structure
| Folder | Contents |
|--------|----------|
| rtl/   | All hardware modules (ALU, register file, pipeline registers, etc.) |
| tb/    | Testbenches for each module |
| sim/   | Simulation outputs (.vcd waveform files) |

## Modules
| Module | Description |
|--------|-------------|
| alu.v | 10-operation ALU |
| register_file.v | 32 x 32-bit registers with write-through |
| control_unit.v | Decodes opcode → control signals |
| forwarding_unit.v | Detects and resolves data hazards |
| hazard_unit.v | Detects load-use hazards, inserts stalls |
| top.v | Connects all 5 pipeline stages |

## Running the Simulation
```bash
iverilog -o sim/cpu_sim.vvp rtl/top.v rtl/alu.v rtl/alu_control.v \
  rtl/register_file.v rtl/instruction_memory.v rtl/pc_register.v \
  rtl/control_unit.v rtl/immediate_gen.v rtl/IF_ID_reg.v \
  rtl/ID_EX_reg.v rtl/EX_MEM_reg.v rtl/MEM_WB_reg.v \
  rtl/data_memory.v rtl/branch_unit.v rtl/forwarding_unit.v \
  rtl/hazard_unit.v tb/tb_top.v

vvp sim/cpu_sim.vvp
```
