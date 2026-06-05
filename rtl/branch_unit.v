// ============================================================
//  Branch Unit
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Decides whether a branch instruction should actually jump.
//
//  RISC-V branch instructions (B-type):
//    beq  rd, rs1, rs2, imm  → jump if rs1 == rs2
//    bne  rd, rs1, rs2, imm  → jump if rs1 != rs2
//    blt  rd, rs1, rs2, imm  → jump if rs1 <  rs2 (signed)
//    bge  rd, rs1, rs2, imm  → jump if rs1 >= rs2 (signed)
//    bltu rd, rs1, rs2, imm  → jump if rs1 <  rs2 (unsigned)
//    bgeu rd, rs1, rs2, imm  → jump if rs1 >= rs2 (unsigned)
//
//  Inputs:
//    branch      from control unit  (1 = this is a branch instr)
//    jump        from control unit  (1 = this is JAL)
//    funct3      bits[14:12]        (which branch type)
//    zero        from ALU           (rs1 - rs2 == 0 means equal)
//    rs1_data    value of rs1       (for signed/unsigned compare)
//    rs2_data    value of rs2
//    pc_plus4    current PC + 4
//    imm         sign-extended immediate (branch offset)
//
//  Outputs:
//    branch_taken  1 = yes, jump to branch_target
//    branch_target address to jump to
//
//  Branch target address = PC of branch instruction + immediate
//  (NOT pc_plus4, the actual PC)
//  We pass pc_plus4 in and subtract 4 to get actual PC
// ============================================================

`timescale 1ns/1ps

module branch_unit (
    input  wire        branch,
    input  wire        jump,
    input  wire [ 2:0] funct3,
    input  wire        zero,
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    input  wire [31:0] pc_plus4,
    input  wire [31:0] imm,
    output reg         branch_taken,
    output reg  [31:0] branch_target
);

    // actual PC = pc_plus4 - 4
    wire [31:0] pc = pc_plus4 - 32'd4;

    // branch target = PC + immediate offset
    wire [31:0] target = pc + imm;

    // signed comparison signals
    wire signed_lt  = ($signed(rs1_data) < $signed(rs2_data));
    wire signed_gte = ($signed(rs1_data) >= $signed(rs2_data));
    wire uint_lt    = (rs1_data < rs2_data);
    wire uint_gte   = (rs1_data >= rs2_data);

    always @(*) begin
        branch_target = target;  // target always computed
        branch_taken  = 1'b0;    // default: not taken

        if (jump) begin
            // JAL always jumps
            branch_taken  = 1'b1;
            branch_target = target;
        end
        else if (branch) begin
            case (funct3)
                3'b000: branch_taken = zero;        // BEQ: taken if equal
                3'b001: branch_taken = ~zero;       // BNE: taken if not equal
                3'b100: branch_taken = signed_lt;   // BLT
                3'b101: branch_taken = signed_gte;  // BGE
                3'b110: branch_taken = uint_lt;     // BLTU
                3'b111: branch_taken = uint_gte;    // BGEU
                default: branch_taken = 1'b0;
            endcase
        end
    end

endmodule