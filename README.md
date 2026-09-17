# RISC-V 5-Stage Pipelined CPU

A 32-bit RV32I RISC-V processor implemented in Verilog from scratch, with a 5-stage pipeline and a SystemVerilog self-checking verification environment.

## Architecture

The processor uses the classic 5-stage pipeline:

**IF → ID → EX → MEM → WB**

### Supported Instructions

* R-type arithmetic and logical operations
* I-type immediate operations
* Load (`lw`)
* Store (`sw`)
* Conditional branch (`beq`)

### Pipeline Features

* 32-bit RV32I datapath
* 32 × 32-bit register file
* 5-stage pipelined execution
* EX/MEM → EX data forwarding
* MEM/WB → EX data forwarding
* Load-use hazard detection
* Automatic pipeline stall and bubble insertion
* Branch resolution in the EX stage
* Wrong-path instruction flushing
* Forwarded operands used for branch decisions

## Project Structure

```text
riscv_pipeline/
├── rtl/
│   ├── alu.v
│   ├── alu_control.v
│   ├── branch_unit.v
│   ├── control_unit.v
│   ├── data_memory.v
│   ├── EX_MEM_reg.v
│   ├── forwarding_unit.v
│   ├── hazard_unit.v
│   ├── ID_EX_reg.v
│   ├── IF_ID_reg.v
│   ├── immediate_gen.v
│   ├── instruction_memory.v
│   ├── MEM_WB_reg.v
│   ├── pc_register.v
│   ├── register_file.v
│   └── top.v
│
├── tb/
│   ├── tb_top.v
│   ├── tb_top.sv
│   └── other module-level testbenches
│
├── sim/
│   └── program.hex
│
└── README.md
```

## Verification

The project includes both module-level Verilog testbenches and a SystemVerilog self-checking testbench for full-pipeline verification.

The full regression exercises:

* Arithmetic and logical instructions
* Register-file operations
* EX/MEM → EX forwarding
* MEM/WB → EX forwarding
* Load-use hazard detection and stalling
* Taken branch and wrong-path instruction flushing
* Not-taken branch and fall-through execution
* Load/store operations
* x0 register invariant

### Regression Result

```text
Results: 18 passed, 0 failed
ALL TESTS PASSED
```

### Assertions

The SystemVerilog testbench (`tb/tb_top.sv`) contains procedural assertions for key pipeline behaviors:

* `x0` remains zero
* Load-use hazards stall the PC
* Load-use hazards stall the IF/ID stage
* Load-use hazards flush the ID/EX stage
* EX/MEM → EX forwarding is selected when required
* MEM/WB → EX forwarding is selected when required
* Taken branches trigger the required pipeline flush behavior

### Functional Coverage Checks

Icarus-compatible procedural coverage checks track whether the regression exercises the defined behaviors:

```text
Branch Taken / Not Taken       = 100% observed
EX/MEM → EX Forwarding         = 100% observed
MEM/WB → EX Forwarding         = 100% observed
Load-Use Hazard                = 100% observed
```

These are **scenario-observation checks**, rather than a claim of 100% overall RTL functional coverage.

Native SystemVerilog `covergroup` support was not used because the project is currently simulated with Icarus Verilog.

## Simulation

### Requirements

* Icarus Verilog
* GTKWave (optional, for waveform inspection)

### Compile

Use SystemVerilog mode for the upgraded testbench:

```bash
iverilog -g2012 -o sim/cpu_sim.vvp \
  rtl/top.v \
  rtl/alu.v \
  rtl/alu_control.v \
  rtl/register_file.v \
  rtl/instruction_memory.v \
  rtl/pc_register.v \
  rtl/control_unit.v \
  rtl/immediate_gen.v \
  rtl/IF_ID_reg.v \
  rtl/ID_EX_reg.v \
  rtl/EX_MEM_reg.v \
  rtl/MEM_WB_reg.v \
  rtl/data_memory.v \
  rtl/branch_unit.v \
  rtl/forwarding_unit.v \
  rtl/hazard_unit.v \
  tb/tb_top.sv
```

### Run

```bash
vvp sim/cpu_sim.vvp
```

The testbench prints the functional test results, assertion failures (if any), and coverage observations.

A VCD waveform can also be generated for inspection in GTKWave.

## Example Verification Output

```text
Results: 18 passed, 0 failed
ALL TESTS PASSED

Functional Coverage

Branch Coverage = 100.00%
EX/MEM -> EX Forwarding = 100.00%
MEM/WB -> EX Forwarding = 100.00%
Load-Use Hazard Coverage = 100.00%
```

## Tools

* **Verilog** — RTL implementation
* **SystemVerilog** — self-checking verification
* **Icarus Verilog** — compilation and simulation
* **GTKWave** — waveform inspection
* **Git/GitHub** — version control

## Author

Anushka
