// ============================================================
//  Instruction Memory
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  This is the ROM (Read Only Memory) that stores your program.
//  Think of it as a long array of 32-bit instructions.
//
//  How it works:
//    - PC (Program Counter) gives an ADDRESS
//    - Instruction Memory returns the 32-bit INSTRUCTION at that address
//    - Read is combinational (instant, no clock needed)
//    - No writing — program is loaded at simulation start
//
//  Addressing:
//    - Each instruction is 4 bytes (32 bits)
//    - PC goes 0, 4, 8, 12, 16... (increments by 4)
//    - We use PC[9:2] to index into our array (word addressing)
//      PC=0  → index 0
//      PC=4  → index 1
//      PC=8  → index 2
//
//  Memory size: 256 words = 256 instructions max (plenty for now)
// ============================================================

`timescale 1ns/1ps

module instruction_memory (
    input  wire [31:0] pc,           // current program counter
    output wire [31:0] instruction   // 32-bit instruction at that address
);

    // 256 locations, each 32 bits wide
    reg [31:0] mem [0:255];

    // Load program from file at simulation start
    initial begin
        $readmemh("sim/program.hex", mem);
    end

    // Read is combinational — PC[9:2] gives word index
    // (divide PC by 4 by dropping bottom 2 bits)
    assign instruction = mem[pc[9:2]];

endmodule