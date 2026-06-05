// ============================================================
//  Data Memory
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  This is the RAM — readable AND writable, unlike instruction
//  memory which is read-only.
//
//  Used by two instructions only:
//    lw  → READ  from memory into a register
//    sw  → WRITE from a register into memory
//
//  How addressing works:
//    address comes from ALU (rs1 + immediate)
//    we use address[9:2] to index into our word array
//    same as instruction memory — bottom 2 bits ignored
//    because every word is 4 bytes and addresses are byte-based
//
//  Read  → combinational (instant, like register file read)
//  Write → sequential    (on clock edge, like register file write)
//
//  Size: 256 words = 1KB of data memory
// ============================================================

`timescale 1ns/1ps

module data_memory (
    input  wire        clk,
    input  wire [31:0] address,     // from ALU result
    input  wire [31:0] write_data,  // from rs2 (for sw)
    input  wire        mem_read,    // 1 = perform a load
    input  wire        mem_write,   // 1 = perform a store
    output wire [31:0] read_data    // data loaded (for lw)
);

    // 256 words of 32-bit memory
    reg [31:0] mem [0:255];

    // Initialize memory to 0
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'b0;
    end

    // ── READ: combinational ───────────────────────────────────
    // If mem_read=1 return the data, else return 0
    assign read_data = (mem_read) ? mem[address[9:2]] : 32'b0;

    // ── WRITE: on rising clock edge ───────────────────────────
    always @(posedge clk) begin
        if (mem_write)
            mem[address[9:2]] <= write_data;
    end

endmodule