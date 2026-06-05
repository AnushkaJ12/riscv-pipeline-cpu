// ============================================================
//  Control Unit
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  This is the BRAIN of the CPU.
//  It looks at the 7-bit opcode of every instruction and
//  outputs control signals that tell every other module
//  what to do this cycle.
//
//  One input  → opcode [6:0]  (bits 6:0 of instruction)
//  Many outputs → one signal per decision the CPU must make
//
//  Control Signals Explained:
//  ┌─────────────┬────────────────────────────────────────────┐
//  │ Signal      │ Meaning                                    │
//  ├─────────────┼────────────────────────────────────────────┤
//  │ reg_write   │ 1 = write result back to register file     │
//  │ mem_read    │ 1 = read from data memory (lw)             │
//  │ mem_write   │ 1 = write to data memory  (sw)             │
//  │ mem_to_reg  │ 1 = WB data comes from memory (lw)         │
//  │             │ 0 = WB data comes from ALU                 │
//  │ alu_src     │ 1 = ALU input B is immediate               │
//  │             │ 0 = ALU input B is register rs2            │
//  │ branch      │ 1 = this is a branch instruction           │
//  │ jump        │ 1 = this is a jump instruction (jal)       │
//  │ alu_op[1:0] │ sent to ALU Control Unit for refinement    │
//  └─────────────┴────────────────────────────────────────────┘
//
//  RISC-V Opcodes:
//    0110011 = R-type  (add, sub, and, or ...)
//    0010011 = I-type  (addi, xori, andi ...)
//    0000011 = Load    (lw)
//    0100011 = Store   (sw)
//    1100011 = Branch  (beq, bne)
//    1101111 = JAL     (jump and link)
//    0110111 = LUI     (load upper immediate)
// ============================================================

`timescale 1ns/1ps

module control_unit (
    input  wire [6:0] opcode,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg,
    output reg        alu_src,
    output reg        branch,
    output reg        jump,
    output reg  [1:0] alu_op
);

    always @(*) begin
        // Default: everything off (safe state)
        reg_write  = 0;
        mem_read   = 0;
        mem_write  = 0;
        mem_to_reg = 0;
        alu_src    = 0;
        branch     = 0;
        jump       = 0;
        alu_op     = 2'b00;

        case (opcode)

            // ── R-type: add, sub, and, or, xor, slt ──────────
            // Uses rs1 and rs2, writes result to rd
            7'b0110011: begin
                reg_write  = 1;   // yes write result to rd
                alu_src    = 0;   // ALU B input = rs2 (register)
                alu_op     = 2'b10; // ALU control decodes funct3/7
            end

            // ── I-type: addi, xori, andi, ori, slti ──────────
            // Uses rs1 and immediate, writes result to rd
            7'b0010011: begin
                reg_write  = 1;   // yes write to rd
                alu_src    = 1;   // ALU B input = immediate
                alu_op     = 2'b10;
            end

            // ── Load: lw ─────────────────────────────────────
            // Address = rs1 + imm, load from memory into rd
            7'b0000011: begin
                reg_write  = 1;   // write loaded value to rd
                mem_read   = 1;   // read from data memory
                mem_to_reg = 1;   // WB mux: pick memory data
                alu_src    = 1;   // ALU computes address: rs1 + imm
                alu_op     = 2'b00; // ALU always ADDs for address
            end

            // ── Store: sw ────────────────────────────────────
            // Address = rs1 + imm, store rs2 into memory
            7'b0100011: begin
                reg_write  = 0;   // no register write for store
                mem_write  = 1;   // write to data memory
                alu_src    = 1;   // ALU computes address: rs1 + imm
                alu_op     = 2'b00; // ALU always ADDs for address
            end

            // ── Branch: beq, bne ─────────────────────────────
            // Compare rs1 and rs2, branch if condition met
            7'b1100011: begin
                reg_write  = 0;   // no register write
                branch     = 1;   // signal: this is a branch
                alu_src    = 0;   // ALU B = rs2 (compare registers)
                alu_op     = 2'b01; // ALU SUBtracts for comparison
            end

            // ── JAL: jump and link ────────────────────────────
            // PC = PC + imm, rd = PC + 4 (return address)
            7'b1101111: begin
                reg_write  = 1;   // write return address to rd
                jump       = 1;   // signal: this is a jump
                alu_src    = 1;
                alu_op     = 2'b00;
            end

            // ── LUI: load upper immediate ─────────────────────
            7'b0110111: begin
                reg_write  = 1;
                alu_src    = 1;
                alu_op     = 2'b00;
            end

            // ── Unknown opcode: all signals off ───────────────
            default: begin
                reg_write  = 0;
                mem_read   = 0;
                mem_write  = 0;
                mem_to_reg = 0;
                alu_src    = 0;
                branch     = 0;
                jump       = 0;
                alu_op     = 2'b00;
            end
        endcase
    end

endmodule