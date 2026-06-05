//  EX/MEM Pipeline Register
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Sits between Stage 3 (EX) and Stage 4 (MEM).
//
//  After EX stage finishes:
//    - ALU has computed its result
//    - Branch condition has been evaluated
//    - rs2 data is ready (for store instructions)
//
//  What gets passed forward:
//    - ALU result       → used as memory address (lw/sw)
//                         or final result (R/I type)
//    - rs2_data         → data to write to memory (sw)
//    - rd_addr          → destination register (still passing forward)
//    - zero flag        → branch decision
//    - control signals  → only the ones MEM/WB still need
// ============================================================

`timescale 1ns/1ps

module EX_MEM_reg (
    input  wire        clk,
    input  wire        reset,

    // ── Control signals (only what MEM+WB need) ──────────────
    input  wire        ex_reg_write,
    input  wire        ex_mem_read,
    input  wire        ex_mem_write,
    input  wire        ex_mem_to_reg,
    input  wire        ex_branch,
    input  wire        ex_jump,

    // ── Data from EX stage ────────────────────────────────────
    input  wire [31:0] ex_alu_result,  // computed by ALU
    input  wire        ex_zero,        // ALU zero flag (for branch)
    input  wire [31:0] ex_rs2_data,    // store data (for sw)
    input  wire [ 4:0] ex_rd_addr,     // destination register
    input  wire [31:0] ex_pc_plus4,    // for JAL return address
    input  wire [31:0] ex_branch_target, // branch destination address

    // ── Outputs to MEM stage ──────────────────────────────────
    output reg         mem_reg_write,
    output reg         mem_mem_read,
    output reg         mem_mem_write,
    output reg         mem_mem_to_reg,
    output reg         mem_branch,
    output reg         mem_jump,

    output reg  [31:0] mem_alu_result,
    output reg         mem_zero,
    output reg  [31:0] mem_rs2_data,
    output reg  [ 4:0] mem_rd_addr,
    output reg  [31:0] mem_pc_plus4,
    output reg  [31:0] mem_branch_target
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_reg_write    <= 0;
            mem_mem_read     <= 0;
            mem_mem_write    <= 0;
            mem_mem_to_reg   <= 0;
            mem_branch       <= 0;
            mem_jump         <= 0;
            mem_alu_result   <= 32'b0;
            mem_zero         <= 1'b0;
            mem_rs2_data     <= 32'b0;
            mem_rd_addr      <= 5'b0;
            mem_pc_plus4     <= 32'b0;
            mem_branch_target<= 32'b0;
        end
        else begin
            mem_reg_write    <= ex_reg_write;
            mem_mem_read     <= ex_mem_read;
            mem_mem_write    <= ex_mem_write;
            mem_mem_to_reg   <= ex_mem_to_reg;
            mem_branch       <= ex_branch;
            mem_jump         <= ex_jump;
            mem_alu_result   <= ex_alu_result;
            mem_zero         <= ex_zero;
            mem_rs2_data     <= ex_rs2_data;
            mem_rd_addr      <= ex_rd_addr;
            mem_pc_plus4     <= ex_pc_plus4;
            mem_branch_target<= ex_branch_target;
        end
    end

endmodule
