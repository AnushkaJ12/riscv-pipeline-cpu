//  ID/EX Pipeline Register
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Sits between Stage 2 (ID) and Stage 3 (EX).
//
//  After ID stage finishes:
//    - Control unit has generated all control signals
//    - Register file has been read (rs1, rs2 values ready)
//    - Immediate has been generated
//    - Instruction fields extracted (rd, rs1_addr, rs2_addr)
//
//  ALL of that gets latched here and passed to EX stage.
//
//  flush = 1 → insert NOP bubble (branch taken / hazard)
//  stall = not needed here (stall is handled by IF/ID + PC)
// ============================================================

`timescale 1ns/1ps

module ID_EX_reg (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,         // 1 = kill this instruction

    // ── Control signals from Control Unit ────────────────────
    input  wire        id_reg_write,
    input  wire        id_mem_read,
    input  wire        id_mem_write,
    input  wire        id_mem_to_reg,
    input  wire        id_alu_src,
    input  wire        id_branch,
    input  wire        id_jump,
    input  wire [1:0]  id_alu_op,

    // ── Data from ID stage ────────────────────────────────────
    input  wire [31:0] id_pc_plus4,
    input  wire [31:0] id_rs1_data,   // value read from rs1
    input  wire [31:0] id_rs2_data,   // value read from rs2
    input  wire [31:0] id_imm,        // sign-extended immediate
    input  wire [ 4:0] id_rs1_addr,   // rs1 register address (for forwarding)
    input  wire [ 4:0] id_rs2_addr,   // rs2 register address (for forwarding)
    input  wire [ 4:0] id_rd_addr,    // destination register address
    input  wire [ 2:0] id_funct3,     // instruction[14:12]
    input  wire        id_funct7_5,   // instruction[30]

    // ── Outputs to EX stage ───────────────────────────────────
    output reg         ex_reg_write,
    output reg         ex_mem_read,
    output reg         ex_mem_write,
    output reg         ex_mem_to_reg,
    output reg         ex_alu_src,
    output reg         ex_branch,
    output reg         ex_jump,
    output reg  [1:0]  ex_alu_op,

    output reg  [31:0] ex_pc_plus4,
    output reg  [31:0] ex_rs1_data,
    output reg  [31:0] ex_rs2_data,
    output reg  [31:0] ex_imm,
    output reg  [ 4:0] ex_rs1_addr,
    output reg  [ 4:0] ex_rs2_addr,
    output reg  [ 4:0] ex_rd_addr,
    output reg  [ 2:0] ex_funct3,
    output reg         ex_funct7_5
);

    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            // Clear all control signals → NOP bubble
            ex_reg_write  <= 0;
            ex_mem_read   <= 0;
            ex_mem_write  <= 0;
            ex_mem_to_reg <= 0;
            ex_alu_src    <= 0;
            ex_branch     <= 0;
            ex_jump       <= 0;
            ex_alu_op     <= 2'b00;
            ex_pc_plus4   <= 32'b0;
            ex_rs1_data   <= 32'b0;
            ex_rs2_data   <= 32'b0;
            ex_imm        <= 32'b0;
            ex_rs1_addr   <= 5'b0;
            ex_rs2_addr   <= 5'b0;
            ex_rd_addr    <= 5'b0;
            ex_funct3     <= 3'b0;
            ex_funct7_5   <= 1'b0;
        end
        else begin
            // Normal: latch everything from ID stage
            ex_reg_write  <= id_reg_write;
            ex_mem_read   <= id_mem_read;
            ex_mem_write  <= id_mem_write;
            ex_mem_to_reg <= id_mem_to_reg;
            ex_alu_src    <= id_alu_src;
            ex_branch     <= id_branch;
            ex_jump       <= id_jump;
            ex_alu_op     <= id_alu_op;
            ex_pc_plus4   <= id_pc_plus4;
            ex_rs1_data   <= id_rs1_data;
            ex_rs2_data   <= id_rs2_data;
            ex_imm        <= id_imm;
            ex_rs1_addr   <= id_rs1_addr;
            ex_rs2_addr   <= id_rs2_addr;
            ex_rd_addr    <= id_rd_addr;
            ex_funct3     <= id_funct3;
            ex_funct7_5   <= id_funct7_5;
        end
    end

endmodule
