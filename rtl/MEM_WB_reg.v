//  MEM/WB Pipeline Register
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Sits between Stage 4 (MEM) and Stage 5 (WB).
//
//  After MEM stage finishes:
//    - Memory has been read (for lw) or written (for sw)
//    - ALU result is still being carried forward
//
//  WB stage needs to decide:
//    mem_to_reg = 1 → write mem_data   back to register (lw)
//    mem_to_reg = 0 → write alu_result back to register (R/I type)
//
//  This is the LAST pipeline register.
//  After WB, the result goes back to the register file.
//  That's the full loop — instruction fetched, executed, written back.
// ============================================================

`timescale 1ns/1ps

module MEM_WB_reg (
    input  wire        clk,
    input  wire        reset,

    // ── Control signals (only what WB needs) ─────────────────
    input  wire        mem_reg_write,
    input  wire        mem_mem_to_reg,

    // ── Data from MEM stage ───────────────────────────────────
    input  wire [31:0] mem_read_data,   // data loaded from memory (lw)
    input  wire [31:0] mem_alu_result,  // ALU result carried through
    input  wire [ 4:0] mem_rd_addr,     // destination register
    input  wire [31:0] mem_pc_plus4,    // for JAL return address

    // ── Outputs to WB stage ───────────────────────────────────
    output reg         wb_reg_write,
    output reg         wb_mem_to_reg,
    output reg  [31:0] wb_read_data,
    output reg  [31:0] wb_alu_result,
    output reg  [ 4:0] wb_rd_addr,
    output reg  [31:0] wb_pc_plus4
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wb_reg_write  <= 0;
            wb_mem_to_reg <= 0;
            wb_read_data  <= 32'b0;
            wb_alu_result <= 32'b0;
            wb_rd_addr    <= 5'b0;
            wb_pc_plus4   <= 32'b0;
        end
        else begin
            wb_reg_write  <= mem_reg_write;
            wb_mem_to_reg <= mem_mem_to_reg;
            wb_read_data  <= mem_read_data;
            wb_alu_result <= mem_alu_result;
            wb_rd_addr    <= mem_rd_addr;
            wb_pc_plus4   <= mem_pc_plus4;
        end
    end

endmodule
