// ============================================================
//  TOP — 5-Stage Pipelined RISC-V CPU
//  Connects all modules: IF → ID → EX → MEM → WB
// ============================================================
//
//  Pipeline flow:
//
//  ┌──────────────────────────────────────────────────────┐
//  │  IF      │  ID       │  EX        │  MEM    │  WB   │
//  │  PC      │  RegFile  │  ALU       │  DMem   │  Mux  │
//  │  IMem    │  CtrlUnit │  FwdMuxes  │         │  →RF  │
//  │          │  ImmGen   │  BranchU   │         │       │
//  │  IF/ID──►│  ID/EX───►│  EX/MEM──►│  MEM/WB►│       │
//  └──────────────────────────────────────────────────────┘
//        ▲                     │
//        └─── branch_taken ────┘  (PC redirected from EX stage)
//
//  Hazard unit  → stalls PC + IF/ID on load-use hazard
//  Forwarding   → bypasses register file for data hazards
// ============================================================

`timescale 1ns/1ps

module top (
    input wire clk,
    input wire reset
);

// ============================================================
//  IF STAGE WIRES
// ============================================================
wire [31:0] if_pc;
wire [31:0] if_pc_plus4;
wire [31:0] if_instruction;

// ============================================================
//  ID STAGE WIRES  (after IF/ID register)
// ============================================================
wire [31:0] id_pc_plus4;
wire [31:0] id_instruction;

// Fields extracted from the instruction word
wire [6:0]  id_opcode   = id_instruction[6:0];
wire [4:0]  id_rs1_addr = id_instruction[19:15];
wire [4:0]  id_rs2_addr = id_instruction[24:20];
wire [4:0]  id_rd_addr  = id_instruction[11:7];
wire [2:0]  id_funct3   = id_instruction[14:12];
wire        id_funct7_5 = id_instruction[30];

// Control signals (from control unit)
wire        id_reg_write, id_mem_read, id_mem_write;
wire        id_mem_to_reg, id_alu_src, id_branch, id_jump;
wire [1:0]  id_alu_op;

// Data (from register file + immediate gen)
wire [31:0] id_rs1_data, id_rs2_data;
wire [31:0] id_imm;

// Hazard unit outputs
wire        hz_pc_write;       // 0 = freeze PC
wire        hz_if_id_write;    // 0 = freeze IF/ID
wire        hz_id_ex_flush;    // 1 = insert bubble into ID/EX

// ============================================================
//  EX STAGE WIRES  (after ID/EX register)
// ============================================================
wire [31:0] ex_pc_plus4;
wire [31:0] ex_rs1_data, ex_rs2_data;
wire [31:0] ex_imm;
wire [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
wire [2:0]  ex_funct3;
wire        ex_funct7_5;

wire        ex_reg_write, ex_mem_read, ex_mem_write;
wire        ex_mem_to_reg, ex_alu_src, ex_branch, ex_jump;
wire [1:0]  ex_alu_op;

// EX computed signals
wire [1:0]  fwd_a, fwd_b;           // forwarding select signals
wire [31:0] ex_alu_input_a;         // ALU operand A (after forwarding)
wire [31:0] ex_fwd_b_data;          // rs2 after forwarding (before alu_src mux)
wire [31:0] ex_alu_input_b;         // ALU operand B (after alu_src mux)
wire [3:0]  ex_alu_ctrl;            // ALU operation
wire [31:0] ex_alu_result;          // ALU output
wire        ex_zero;                // ALU zero flag
wire        ex_branch_taken;        // branch/jump decision
wire [31:0] ex_branch_target;       // address to jump to

// WB data (needed for MEM/WB forwarding back to EX)
wire [31:0] wb_write_data;

// ============================================================
//  MEM STAGE WIRES  (after EX/MEM register)
// ============================================================
wire [31:0] mem_alu_result;
wire [31:0] mem_rs2_data;
wire [ 4:0] mem_rd_addr;
wire [31:0] mem_pc_plus4;
wire [31:0] mem_branch_target;
wire        mem_zero;

wire        mem_reg_write, mem_mem_read, mem_mem_write;
wire        mem_mem_to_reg, mem_branch, mem_jump;

wire [31:0] mem_read_data;          // data loaded from data memory

// ============================================================
//  WB STAGE WIRES  (after MEM/WB register)
// ============================================================
wire [31:0] wb_alu_result;
wire [31:0] wb_read_data;
wire [ 4:0] wb_rd_addr;
wire [31:0] wb_pc_plus4;
wire        wb_reg_write, wb_mem_to_reg;

// ============================================================
//  IF STAGE
// ============================================================

// PC Register
// stall = ~hz_pc_write  (hazard says freeze → stall=1)
// branch_taken comes from EX stage branch unit
pc_register u_pc (
    .clk          (clk),
    .reset        (reset),
    .stall        (~hz_pc_write),
    .branch_taken (ex_branch_taken),
    .branch_target(ex_branch_target),
    .pc_out       (if_pc),
    .pc_plus4     (if_pc_plus4)
);

// Instruction Memory
instruction_memory u_imem (
    .pc          (if_pc),
    .instruction (if_instruction)
);

// IF/ID Pipeline Register
// stall = ~hz_if_id_write  (hazard freeze)
// flush = ex_branch_taken   (branch taken → kill wrong instruction)
IF_ID_reg u_if_id (
    .clk           (clk),
    .reset         (reset),
    .stall         (~hz_if_id_write),
    .flush         (ex_branch_taken),
    .if_pc_plus4   (if_pc_plus4),
    .if_instruction(if_instruction),
    .id_pc_plus4   (id_pc_plus4),
    .id_instruction(id_instruction)
);

// ============================================================
//  ID STAGE
// ============================================================

// Control Unit
control_unit u_ctrl (
    .opcode     (id_opcode),
    .reg_write  (id_reg_write),
    .mem_read   (id_mem_read),
    .mem_write  (id_mem_write),
    .mem_to_reg (id_mem_to_reg),
    .alu_src    (id_alu_src),
    .branch     (id_branch),
    .jump       (id_jump),
    .alu_op     (id_alu_op)
);

// Register File
// Write port connected to WB stage
register_file u_regfile (
    .clk       (clk),
    .rs1_addr  (id_rs1_addr),
    .rs2_addr  (id_rs2_addr),
    .rs1_data  (id_rs1_data),
    .rs2_data  (id_rs2_data),
    .rd_addr   (wb_rd_addr),
    .rd_data   (wb_write_data),
    .reg_write (wb_reg_write)
);

// Immediate Generator
immediate_gen u_immgen (
    .instruction (id_instruction),
    .imm_out     (id_imm)
);

// Hazard Detection Unit
// Looks at EX stage (ID/EX outputs) vs ID stage (IF/ID outputs)
hazard_unit u_hazard (
    .id_ex_mem_read (ex_mem_read),   // is the instr in EX a load?
    .id_ex_rd       (ex_rd_addr),    // its destination register
    .if_id_rs1      (id_rs1_addr),   // rs1 of instr in ID
    .if_id_rs2      (id_rs2_addr),   // rs2 of instr in ID
    .pc_write       (hz_pc_write),
    .if_id_write    (hz_if_id_write),
    .id_ex_flush    (hz_id_ex_flush)
);

// ID/EX Pipeline Register
// flush when: hazard unit says flush OR branch was taken
ID_EX_reg u_id_ex (
    .clk          (clk),
    .reset        (reset),
    .flush        (hz_id_ex_flush | ex_branch_taken),
    // control signals
    .id_reg_write (id_reg_write),
    .id_mem_read  (id_mem_read),
    .id_mem_write (id_mem_write),
    .id_mem_to_reg(id_mem_to_reg),
    .id_alu_src   (id_alu_src),
    .id_branch    (id_branch),
    .id_jump      (id_jump),
    .id_alu_op    (id_alu_op),
    // data
    .id_pc_plus4  (id_pc_plus4),
    .id_rs1_data  (id_rs1_data),
    .id_rs2_data  (id_rs2_data),
    .id_imm       (id_imm),
    .id_rs1_addr  (id_rs1_addr),
    .id_rs2_addr  (id_rs2_addr),
    .id_rd_addr   (id_rd_addr),
    .id_funct3    (id_funct3),
    .id_funct7_5  (id_funct7_5),
    // outputs to EX
    .ex_reg_write (ex_reg_write),
    .ex_mem_read  (ex_mem_read),
    .ex_mem_write (ex_mem_write),
    .ex_mem_to_reg(ex_mem_to_reg),
    .ex_alu_src   (ex_alu_src),
    .ex_branch    (ex_branch),
    .ex_jump      (ex_jump),
    .ex_alu_op    (ex_alu_op),
    .ex_pc_plus4  (ex_pc_plus4),
    .ex_rs1_data  (ex_rs1_data),
    .ex_rs2_data  (ex_rs2_data),
    .ex_imm       (ex_imm),
    .ex_rs1_addr  (ex_rs1_addr),
    .ex_rs2_addr  (ex_rs2_addr),
    .ex_rd_addr   (ex_rd_addr),
    .ex_funct3    (ex_funct3),
    .ex_funct7_5  (ex_funct7_5)
);

// ============================================================
//  EX STAGE
// ============================================================

// Forwarding Unit
forwarding_unit u_fwd (
    .id_ex_rs1        (ex_rs1_addr),
    .id_ex_rs2        (ex_rs2_addr),
    .ex_mem_rd        (mem_rd_addr),
    .ex_mem_reg_write (mem_reg_write),
    .mem_wb_rd        (wb_rd_addr),
    .mem_wb_reg_write (wb_reg_write),
    .forward_a        (fwd_a),
    .forward_b        (fwd_b)
);

// Forwarding Mux A  (selects ALU operand A = rs1)
//   00 → register file value
//   10 → forward from EX/MEM (1 cycle ago)
//   01 → forward from MEM/WB (2 cycles ago)
assign ex_alu_input_a = (fwd_a == 2'b10) ? mem_alu_result :
                        (fwd_a == 2'b01) ? wb_write_data  :
                                           ex_rs1_data;

// Forwarding Mux B  (selects rs2 value after forwarding)
assign ex_fwd_b_data  = (fwd_b == 2'b10) ? mem_alu_result :
                        (fwd_b == 2'b01) ? wb_write_data  :
                                           ex_rs2_data;

// ALU Source Mux B  (selects between register rs2 OR immediate)
//   alu_src=0 → use rs2 (R-type, branch)
//   alu_src=1 → use immediate (I-type, load, store)
assign ex_alu_input_b = ex_alu_src ? ex_imm : ex_fwd_b_data;

// ALU Control Unit
alu_control u_alu_ctrl (
    .alu_op   (ex_alu_op),
    .funct3   (ex_funct3),
    .funct7_5 (ex_funct7_5),
    .is_imm   (ex_alu_src),    // 1 for I-type: don't use funct7
    .alu_ctrl (ex_alu_ctrl)
);

// ALU
alu u_alu (
    .a        (ex_alu_input_a),
    .b        (ex_alu_input_b),
    .alu_ctrl (ex_alu_ctrl),
    .result   (ex_alu_result),
    .zero     (ex_zero)
);

// Branch Unit
branch_unit u_branch (
    .branch       (ex_branch),
    .jump         (ex_jump),
    .funct3       (ex_funct3),
    .zero         (ex_zero),
    .rs1_data     (ex_alu_input_a),   // forwarded rs1
    .rs2_data     (ex_fwd_b_data),    // forwarded rs2
    .pc_plus4     (ex_pc_plus4),
    .imm          (ex_imm),
    .branch_taken (ex_branch_taken),
    .branch_target(ex_branch_target)
);

// EX/MEM Pipeline Register
EX_MEM_reg u_ex_mem (
    .clk              (clk),
    .reset            (reset),
    .ex_reg_write     (ex_reg_write),
    .ex_mem_read      (ex_mem_read),
    .ex_mem_write     (ex_mem_write),
    .ex_mem_to_reg    (ex_mem_to_reg),
    .ex_branch        (ex_branch),
    .ex_jump          (ex_jump),
    .ex_alu_result    (ex_alu_result),
    .ex_zero          (ex_zero),
    .ex_rs2_data      (ex_fwd_b_data),  // forwarded value for sw
    .ex_rd_addr       (ex_rd_addr),
    .ex_pc_plus4      (ex_pc_plus4),
    .ex_branch_target (ex_branch_target),
    .mem_reg_write    (mem_reg_write),
    .mem_mem_read     (mem_mem_read),
    .mem_mem_write    (mem_mem_write),
    .mem_mem_to_reg   (mem_mem_to_reg),
    .mem_branch       (mem_branch),
    .mem_jump         (mem_jump),
    .mem_alu_result   (mem_alu_result),
    .mem_zero         (mem_zero),
    .mem_rs2_data     (mem_rs2_data),
    .mem_rd_addr      (mem_rd_addr),
    .mem_pc_plus4     (mem_pc_plus4),
    .mem_branch_target(mem_branch_target)
);

// ============================================================
//  MEM STAGE
// ============================================================

// Data Memory
data_memory u_dmem (
    .clk        (clk),
    .address    (mem_alu_result),   // address = ALU result (rs1 + imm)
    .write_data (mem_rs2_data),     // data to store (rs2 value)
    .mem_read   (mem_mem_read),
    .mem_write  (mem_mem_write),
    .read_data  (mem_read_data)
);

// MEM/WB Pipeline Register
MEM_WB_reg u_mem_wb (
    .clk          (clk),
    .reset        (reset),
    .mem_reg_write(mem_reg_write),
    .mem_mem_to_reg(mem_mem_to_reg),
    .mem_read_data(mem_read_data),
    .mem_alu_result(mem_alu_result),
    .mem_rd_addr  (mem_rd_addr),
    .mem_pc_plus4 (mem_pc_plus4),
    .wb_reg_write (wb_reg_write),
    .wb_mem_to_reg(wb_mem_to_reg),
    .wb_read_data (wb_read_data),
    .wb_alu_result(wb_alu_result),
    .wb_rd_addr   (wb_rd_addr),
    .wb_pc_plus4  (wb_pc_plus4)
);

// ============================================================
//  WB STAGE
// ============================================================
// Write-back mux:
//   mem_to_reg = 1 → write loaded memory data (lw)
//   mem_to_reg = 0 → write ALU result (R/I-type)
assign wb_write_data = wb_mem_to_reg ? wb_read_data : wb_alu_result;

// wb_write_data + wb_rd_addr + wb_reg_write
// all feed back to register_file write port (instantiated in ID stage above)

endmodule