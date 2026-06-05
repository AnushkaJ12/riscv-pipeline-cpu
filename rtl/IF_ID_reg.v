// ============================================================
//  IF/ID Pipeline Register
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  This register sits BETWEEN Stage 1 (IF) and Stage 2 (ID).
//  It captures the outputs of IF at the end of each clock cycle
//  and holds them steady for ID to use in the next cycle.
//
//  Think of it as a "snapshot" — IF finishes its work,
//  takes a photo of its outputs, and passes that photo to ID.
//
//  Without pipeline registers, all 5 stages would fight over
//  the same wires at the same time. The registers SEPARATE them.
//
//  What gets passed from IF to ID:
//    - pc_plus4    : PC+4 (needed later for branch/jump calc)
//    - instruction : the 32-bit fetched instruction
//
//  Special controls:
//    stall  : 1 = freeze this register (hold current values)
//             Used when a hazard is detected downstream
//    flush  : 1 = clear to NOP (insert a bubble)
//             Used when a branch is taken (wrong instructions fetched)
//
//  NOP in RISC-V = 32'h00000013 = addi x0, x0, 0
//    (writes to x0 which is discarded → does nothing)
// ============================================================

`timescale 1ns/1ps

module IF_ID_reg (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,        // 1 = hold current values
    input  wire        flush,        // 1 = insert NOP bubble
    // Inputs from IF stage
    input  wire [31:0] if_pc_plus4,
    input  wire [31:0] if_instruction,
    // Outputs to ID stage
    output reg  [31:0] id_pc_plus4,
    output reg  [31:0] id_instruction
);

    // NOP instruction: addi x0, x0, 0 → does absolutely nothing
    localparam NOP = 32'h00000013;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            id_pc_plus4    <= 32'b0;
            id_instruction <= NOP;
        end
        else if (flush) begin
            // Branch was taken: kill the wrongly-fetched instruction
            // Replace with NOP so it causes no side effects
            id_pc_plus4    <= 32'b0;
            id_instruction <= NOP;
        end
        else if (stall) begin
            // Hazard detected: freeze everything, don't update
            id_pc_plus4    <= id_pc_plus4;
            id_instruction <= id_instruction;
        end
        else begin
            // Normal operation: latch IF outputs
            id_pc_plus4    <= if_pc_plus4;
            id_instruction <= if_instruction;
        end
    end

endmodule