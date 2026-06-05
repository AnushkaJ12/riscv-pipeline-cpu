// ============================================================
//  Hazard Detection Unit
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Handles the ONE case forwarding cannot fix:
//
//  LOAD-USE HAZARD:
//    lw  x1, 0(x2)      ← in EX,  result won't exist until MEM
//    sub x4, x1, x5     ← in ID,  will need x1 next cycle in EX
//
//  Timeline without stall:
//    Cycle 3: lw  in EX  → reads memory
//    Cycle 4: lw  in MEM → data available HERE
//             sub in EX  → needs x1 HERE ← one cycle too early!
//
//  Fix: insert ONE bubble (stall for 1 cycle)
//    Cycle 3: lw  in EX
//    Cycle 4: lw  in MEM  |  BUBBLE in EX  |  sub still in ID (frozen)
//    Cycle 5: lw  in WB   |  sub in EX     ← now MEM/WB forwarding works!
//
//  How to stall:
//    1. pc_write   = 0  → freeze PC (don't fetch next instruction)
//    2. if_id_write = 0 → freeze IF/ID register (keep current instruction)
//    3. id_ex_flush = 1 → flush ID/EX register  (insert NOP bubble)
//
//  Detection condition:
//    The instruction in EX is a LOAD (mem_read = 1)
//    AND its destination register matches rs1 OR rs2 of instruction in ID
//    AND destination is not x0
// ============================================================

`timescale 1ns/1ps

module hazard_unit (
    // Instruction currently in EX stage
    input  wire       id_ex_mem_read,  // 1 = it's a load instruction
    input  wire [4:0] id_ex_rd,        // its destination register

    // Instruction currently in ID stage (the one that might need the value)
    input  wire [4:0] if_id_rs1,       // rs1 of instruction in ID
    input  wire [4:0] if_id_rs2,       // rs2 of instruction in ID

    // Stall control outputs
    output reg        pc_write,        // 0 = freeze PC
    output reg        if_id_write,     // 0 = freeze IF/ID register
    output reg        id_ex_flush      // 1 = flush ID/EX (insert bubble)
);

    always @(*) begin
        // Default: no stall, everything runs normally
        pc_write    = 1'b1;   // PC updates normally
        if_id_write = 1'b1;   // IF/ID updates normally
        id_ex_flush = 1'b0;   // no bubble

        // Detect load-use hazard
        if (id_ex_mem_read &&              // EX instruction is a load
            (id_ex_rd != 5'b0) &&          // destination is not x0
            ((id_ex_rd == if_id_rs1) ||    // matches rs1 of next instr
             (id_ex_rd == if_id_rs2)))     // OR rs2 of next instr
        begin
            pc_write    = 1'b0;   // freeze PC
            if_id_write = 1'b0;   // freeze IF/ID (re-decode same instr)
            id_ex_flush = 1'b1;   // insert NOP bubble into EX
        end
    end

endmodule
