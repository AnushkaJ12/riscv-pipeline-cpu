// ============================================================
//  Immediate Generator
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  RISC-V instructions encode immediate values (constants)
//  in different BIT POSITIONS depending on instruction type.
//  This module extracts those bits and sign-extends to 32 bits.
//
//  What is sign extension?
//    If your immediate is 12 bits and the MSB (bit 11) = 1
//    (meaning it's negative), you fill the upper 20 bits with 1s
//    to keep the negative value correct in 32-bit math.
//    If MSB = 0 (positive), fill upper bits with 0s.
//
//  Instruction formats and where the immediate bits live:
//
//  I-type: [31:20] = imm[11:0]
//    Used by: addi, lw, jalr
//
//  S-type: [31:25] = imm[11:5], [11:7] = imm[4:0]
//    Used by: sw
//    (split across two fields — we reassemble them)
//
//  B-type: [31]=imm[12], [30:25]=imm[10:5],
//          [11:8]=imm[4:1], [7]=imm[11]
//    Used by: beq, bne
//    (most scrambled — branch offsets are word-aligned)
//
//  U-type: [31:12] = imm[31:12], lower 12 bits = 0
//    Used by: lui, auipc
//
//  J-type: [31]=imm[20], [30:21]=imm[10:1],
//          [20]=imm[11], [19:12]=imm[19:12]
//    Used by: jal
// ============================================================

`timescale 1ns/1ps

module immediate_gen (
    input  wire [31:0] instruction,
    output reg  [31:0] imm_out
);

    // opcode tells us which format to use
    wire [6:0] opcode = instruction[6:0];

    always @(*) begin
        case (opcode)

            // ── I-type: addi, lw, jalr ────────────────────────
            7'b0010011,   // I-type ALU
            7'b0000011,   // Load
            7'b1100111:   // JALR
                // bits [31:20] are the immediate, sign extend from bit 31
                imm_out = {{20{instruction[31]}}, instruction[31:20]};

            // ── S-type: sw ────────────────────────────────────
            7'b0100011:
                // upper part [31:25] + lower part [11:7] reassembled
                imm_out = {{20{instruction[31]}},
                            instruction[31:25],
                            instruction[11:7]};

            // ── B-type: beq, bne ──────────────────────────────
            7'b1100011:
                // most scrambled format — bits are reordered
                // bit 0 is always 0 (branch targets are 2-byte aligned)
                imm_out = {{19{instruction[31]}},
                            instruction[31],
                            instruction[7],
                            instruction[30:25],
                            instruction[11:8],
                            1'b0};

            // ── U-type: lui ───────────────────────────────────
            7'b0110111,   // LUI
            7'b0010111:   // AUIPC
                // upper 20 bits of instruction become upper 20 bits of imm
                // lower 12 bits zeroed out
                imm_out = {instruction[31:12], 12'b0};

            // ── J-type: jal ───────────────────────────────────
            7'b1101111:
                imm_out = {{11{instruction[31]}},
                            instruction[31],
                            instruction[19:12],
                            instruction[20],
                            instruction[30:21],
                            1'b0};

            // ── Default: zero ─────────────────────────────────
            default:
                imm_out = 32'b0;

        endcase
    end

endmodule