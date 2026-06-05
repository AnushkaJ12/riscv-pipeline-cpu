// ============================================================
//  ALU Control Unit
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  This sits BETWEEN the main Control Unit and the ALU.
//  The main control unit gives a 2-bit alu_op.
//  This unit refines it using funct3 + funct7 to produce
//  the exact 4-bit alu_ctrl signal the ALU needs.
//
//  alu_op encoding (from main Control Unit):
//    2'b00  → ADD  (for load/store address calculation)
//    2'b01  → SUB  (for branch comparison)
//    2'b10  → look at funct3/funct7 (R-type and I-type)
//
//  Inputs:
//    alu_op   [1:0]  from main control unit
//    funct3   [2:0]  bits [14:12] of instruction
//    funct7_5 [0:0]  bit  [30]    of instruction (SUB vs ADD, SRA vs SRL)
//    is_imm          1 = I-type immediate (ignore funct7 for ADD/SRL)
//
//  Output:
//    alu_ctrl [3:0]  sent directly to ALU
// ============================================================

`timescale 1ns/1ps

module alu_control (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire       funct7_5,   // instruction[30]
    input  wire       is_imm,     // 1 for I-type (addi, xori, etc.)
    output reg  [3:0] alu_ctrl
);

    always @(*) begin
        case (alu_op)
            // Load / Store → always ADD (base + offset)
            2'b00: alu_ctrl = 4'b0000;  // ADD

            // Branch → always SUB (a - b, check zero flag)
            2'b01: alu_ctrl = 4'b0001;  // SUB

            // R-type or I-type: decode funct3 (and funct7 for R-type)
            2'b10: begin
                case (funct3)
                    3'b000: begin
                        // ADD vs SUB: funct7[5]=1 AND it's R-type → SUB
                        if (funct7_5 && !is_imm)
                            alu_ctrl = 4'b0001; // SUB
                        else
                            alu_ctrl = 4'b0000; // ADD / ADDI
                    end
                    3'b001: alu_ctrl = 4'b0101; // SLL / SLLI
                    3'b010: alu_ctrl = 4'b1000; // SLT / SLTI
                    3'b011: alu_ctrl = 4'b1001; // SLTU / SLTIU
                    3'b100: alu_ctrl = 4'b0100; // XOR / XORI
                    3'b101: begin
                        // SRL vs SRA
                        if (funct7_5)
                            alu_ctrl = 4'b0111; // SRA / SRAI
                        else
                            alu_ctrl = 4'b0110; // SRL / SRLI
                    end
                    3'b110: alu_ctrl = 4'b0011; // OR  / ORI
                    3'b111: alu_ctrl = 4'b0010; // AND / ANDI
                    default: alu_ctrl = 4'b0000;
                endcase
            end

            default: alu_ctrl = 4'b0000;
        endcase
    end

endmodule