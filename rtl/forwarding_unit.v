// ============================================================
//  Forwarding Unit
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Detects when the EX stage needs a value that hasn't been
//  written back to the register file yet, and forwards it
//  directly from a later pipeline register.
//
//  Two forwarding paths exist:
//
//  EX/MEM → EX  (forward from instruction 1 cycle ahead)
//    Example:
//      add x1, x2, x3    ← in MEM, result in EX_MEM register
//      sub x4, x1, x5    ← in EX,  needs x1 RIGHT NOW
//    Fix: forward EX_MEM_alu_result directly to ALU input A
//
//  MEM/WB → EX  (forward from instruction 2 cycles ahead)
//    Example:
//      add x1, x2, x3    ← in WB,  result in MEM_WB register
//      nop               ← in MEM
//      sub x4, x1, x5    ← in EX,  needs x1 RIGHT NOW
//    Fix: forward MEM_WB result directly to ALU input A
//
//  Output encoding for forward_a and forward_b:
//    2'b00  → no forwarding, use register file value (normal)
//    2'b10  → forward from EX/MEM pipeline register
//    2'b01  → forward from MEM/WB pipeline register
//
//  Conditions to forward from EX/MEM:
//    1. EX/MEM instruction writes a register  (ex_mem_reg_write)
//    2. EX/MEM destination is not x0          (ex_mem_rd != 0)
//    3. EX/MEM destination matches EX source  (ex_mem_rd == id_ex_rs1/rs2)
//
//  Conditions to forward from MEM/WB:
//    Same but for MEM/WB register
//    AND EX/MEM isn't already forwarding (EX/MEM takes priority)
// ============================================================

`timescale 1ns/1ps

module forwarding_unit (
    // Source register addresses of instruction currently in EX
    input  wire [4:0] id_ex_rs1,      // rs1 address in EX stage
    input  wire [4:0] id_ex_rs2,      // rs2 address in EX stage

    // EX/MEM pipeline register info
    input  wire [4:0] ex_mem_rd,      // destination reg of instr in MEM
    input  wire       ex_mem_reg_write, // does that instr write a reg?

    // MEM/WB pipeline register info
    input  wire [4:0] mem_wb_rd,      // destination reg of instr in WB
    input  wire       mem_wb_reg_write, // does that instr write a reg?

    // Forwarding control outputs
    output reg  [1:0] forward_a,      // for ALU input A (rs1)
    output reg  [1:0] forward_b       // for ALU input B (rs2)
);

    always @(*) begin
        // ── Forward A (rs1) ───────────────────────────────────
        // Default: no forwarding
        forward_a = 2'b00;

        // EX/MEM hazard has priority over MEM/WB hazard
        if (ex_mem_reg_write &&
            (ex_mem_rd != 5'b0) &&
            (ex_mem_rd == id_ex_rs1))
        begin
            forward_a = 2'b10;   // forward from EX/MEM
        end
        else if (mem_wb_reg_write &&
                 (mem_wb_rd != 5'b0) &&
                 (mem_wb_rd == id_ex_rs1))
        begin
            forward_a = 2'b01;   // forward from MEM/WB
        end

        // ── Forward B (rs2) ───────────────────────────────────
        forward_b = 2'b00;

        if (ex_mem_reg_write &&
            (ex_mem_rd != 5'b0) &&
            (ex_mem_rd == id_ex_rs2))
        begin
            forward_b = 2'b10;   // forward from EX/MEM
        end
        else if (mem_wb_reg_write &&
                 (mem_wb_rd != 5'b0) &&
                 (mem_wb_rd == id_ex_rs2))
        begin
            forward_b = 2'b01;   // forward from MEM/WB
        end
    end

endmodule