// ============================================================
//  Program Counter (PC) Register
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  The PC holds the ADDRESS of the NEXT instruction to fetch.
//
//  Every clock cycle it either:
//    - Moves to PC + 4        (next instruction, normal flow)
//    - Jumps to branch_target (when a branch/jump is taken)
//    - Stays the same         (when hazard unit says stall)
//
//  Ports:
//    clk           clock
//    reset         1 = go back to address 0
//    stall         1 = freeze PC (don't move, hazard is happening)
//    branch_taken  1 = jump to branch_target instead of PC+4
//    branch_target address to jump to on branch
//    pc_out        current PC value (goes to instruction memory)
//    pc_plus4      PC + 4 (passed down pipeline for later use)
// ============================================================

`timescale 1ns/1ps

module pc_register (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,
    input  wire        branch_taken,
    input  wire [31:0] branch_target,
    output reg  [31:0] pc_out,
    output wire [31:0] pc_plus4
);

    // PC+4 is always current PC + 4 (next sequential instruction)
    assign pc_plus4 = pc_out + 32'd4;

    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_out <= 32'b0;           // reset → start from address 0
        else if (stall)
            pc_out <= pc_out;          // stall → freeze, don't move
        else if (branch_taken)
            pc_out <= branch_target;   // branch → jump to target
        else
            pc_out <= pc_plus4;        // normal → go to next instruction
    end

endmodule