// ============================================================
//  ALU — Arithmetic Logic Unit
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Inputs:
//    a        [31:0]  — operand A (from register rs1)
//    b        [31:0]  — operand B (register rs2 OR immediate)
//    alu_ctrl [ 3:0]  — operation select (from ALU Control Unit)
//
//  Outputs:
//    result   [31:0]  — computed result
//    zero             — 1 if result == 0  (used by branch logic)
//
//  Operation encoding (alu_ctrl):
//    4'b0000  ADD
//    4'b0001  SUB
//    4'b0010  AND
//    4'b0011  OR
//    4'b0100  XOR
//    4'b0101  SLL  (shift left logical)
//    4'b0110  SRL  (shift right logical)
//    4'b0111  SRA  (shift right arithmetic)
//    4'b1000  SLT  (set less than, signed)
//    4'b1001  SLTU (set less than, unsigned)
// ============================================================

`timescale 1ns/1ps

module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [ 3:0] alu_ctrl,
    output reg  [31:0] result,
    output wire        zero
);

    // zero flag: high when result is 0 (used for BEQ/BNE)
    assign zero = (result == 32'b0);

    // shift amount comes from lower 5 bits of b
    wire [4:0] shamt = b[4:0];

    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a + b;                          // ADD
            4'b0001: result = a - b;                          // SUB
            4'b0010: result = a & b;                          // AND
            4'b0011: result = a | b;                          // OR
            4'b0100: result = a ^ b;                          // XOR
            4'b0101: result = a << shamt;                     // SLL
            4'b0110: result = a >> shamt;                     // SRL
            4'b0111: result = $signed(a) >>> shamt;           // SRA
            4'b1000: result = ($signed(a) < $signed(b))       // SLT
                               ? 32'd1 : 32'd0;
            4'b1001: result = (a < b) ? 32'd1 : 32'd0;       // SLTU
            default: result = 32'b0;                          // safety default
        endcase
    end
endmodule