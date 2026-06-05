// ============================================================
//  Register File
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  RISC-V has 32 general-purpose registers: x0 to x31
//  Each register is 32 bits wide.
//
//  Key rules:
//    - x0 is HARDWIRED to 0. Writing to it does nothing.
//    - Two READ ports (rs1, rs2) — read happens every cycle
//    - One WRITE port (rd)       — write happens on clock edge
//
//  Why 2 read ports?
//    Most R-type instructions need TWO source registers.
//    e.g.  add x3, x1, x2  → need to read x1 AND x2 same cycle
//
//  Ports:
//    clk              clock
//    rs1_addr [4:0]   address of source register 1  (0–31)
//    rs2_addr [4:0]   address of source register 2  (0–31)
//    rd_addr  [4:0]   address of destination register
//    rd_data  [31:0]  data to write into rd
//    reg_write        1 = write enabled, 0 = no write
//    rs1_data [31:0]  data read from rs1
//    rs2_data [31:0]  data read from rs2
// ============================================================

`timescale 1ns/1ps

module register_file (
    input  wire        clk,
    // Read ports
    input  wire [ 4:0] rs1_addr,
    input  wire [ 4:0] rs2_addr,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,
    // Write port
    input  wire [ 4:0] rd_addr,
    input  wire [31:0] rd_data,
    input  wire        reg_write
);

    // 32 registers, each 32 bits wide
    reg [31:0] registers [0:31];

    // ── Initialize all registers to 0 ────────────────────────
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] = 32'b0;
    end

    // ── READ (combinational — instant, no clock needed) ──────
    // x0 is hardwired to 0: if address is 0, always return 0
   assign rs1_data = (rs1_addr == 5'b0)                ? 32'b0   :
                  (reg_write && rd_addr == rs1_addr) ? rd_data :
                  registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'b0)                       ? 32'b0   :
                  (reg_write && rd_addr == rs2_addr)        ? rd_data :
                  registers[rs2_addr];

    // ── WRITE (sequential — only on rising clock edge) ───────
    always @(posedge clk) begin
        if (reg_write && rd_addr != 5'b0)   // never write to x0
            registers[rd_addr] <= rd_data;
    end

endmodule