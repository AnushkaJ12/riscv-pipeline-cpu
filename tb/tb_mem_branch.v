// ============================================================
//  Testbench — Data Memory + Branch Unit
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Run:
//    iverilog -o sim/mem_branch_sim.vvp rtl/data_memory.v rtl/branch_unit.v tb/tb_mem_branch.v
//    vvp sim/mem_branch_sim.vvp
// ============================================================

`timescale 1ns/1ps

module tb_mem_branch;

    integer pass_count, fail_count;

    reg clk;
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/mem_branch_dump.vcd");
        $dumpvars(0, tb_mem_branch);
    end

    task check;
        input [31:0] actual;
        input [31:0] expected;
        input [80*8:1] name;
        begin
            if (actual === expected) begin
                $display("  PASS  %-38s | got=0x%08h", name, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-38s | got=0x%08h exp=0x%08h",
                         name, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ═══════════════════════════════════════════════════════════
    //  DATA MEMORY
    // ═══════════════════════════════════════════════════════════
    reg [31:0] address, write_data;
    reg        mem_read, mem_write;
    wire[31:0] read_data;

    data_memory uut_dmem (
        .clk        (clk),
        .address    (address),
        .write_data (write_data),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .read_data  (read_data)
    );

    // ═══════════════════════════════════════════════════════════
    //  BRANCH UNIT
    // ═══════════════════════════════════════════════════════════
    reg        branch, jump;
    reg [2:0]  funct3;
    reg        zero;
    reg [31:0] rs1_data, rs2_data, pc_plus4, imm;
    wire       branch_taken;
    wire[31:0] branch_target;

    branch_unit uut_bu (
        .branch       (branch),
        .jump         (jump),
        .funct3       (funct3),
        .zero         (zero),
        .rs1_data     (rs1_data),
        .rs2_data     (rs2_data),
        .pc_plus4     (pc_plus4),
        .imm          (imm),
        .branch_taken (branch_taken),
        .branch_target(branch_target)
    );

    initial begin
        pass_count = 0; fail_count = 0;
        mem_read = 0; mem_write = 0;
        address = 0; write_data = 0;
        branch = 0; jump = 0; funct3 = 0;
        zero = 0; rs1_data = 0; rs2_data = 0;
        pc_plus4 = 0; imm = 0;

        $display("\n========================================");
        $display("  Data Memory + Branch Unit Testbench");
        $display("========================================");

        // ── DATA MEMORY: Write then read ──────────────────────
        $display("\n--- Data Memory: Store (sw) ---");

        // sw: write 42 to address 0
        @(negedge clk);
        address = 32'd0; write_data = 32'd42; mem_write = 1;
        @(posedge clk); #1;
        mem_write = 0;

        // lw: read back from address 0
        address = 32'd0; mem_read = 1; #1;
        check(read_data, 32'd42, "store 42 @ addr 0, load back");

        // sw: write 0xDEADBEEF to address 4
        @(negedge clk);
        address = 32'd4; write_data = 32'hDEADBEEF; mem_write = 1;
        @(posedge clk); #1;
        mem_write = 0;

        address = 32'd4; mem_read = 1; #1;
        check(read_data, 32'hDEADBEEF, "store 0xDEADBEEF @ addr 4");

        // address 0 should still be 42
        address = 32'd0; mem_read = 1; #1;
        check(read_data, 32'd42, "addr 0 still holds 42");

        $display("\n--- Data Memory: mem_read=0 returns 0 ---");
        address = 32'd0; mem_read = 0; #1;
        check(read_data, 32'd0, "mem_read=0: output is 0");

        // ── BRANCH UNIT: BEQ ──────────────────────────────────
        $display("\n--- Branch Unit: BEQ (beq) ---");
        branch = 1; funct3 = 3'b000; // BEQ
        pc_plus4 = 32'd8; imm = 32'd16; // target = (8-4)+16 = 20

        zero = 1; #1; // equal → taken
        check({31'b0, branch_taken}, 32'd1, "BEQ: zero=1 → taken");
        check(branch_target, 32'd20, "BEQ: target = PC+imm = 20");

        zero = 0; #1; // not equal → not taken
        check({31'b0, branch_taken}, 32'd0, "BEQ: zero=0 → not taken");

        // ── BRANCH UNIT: BNE ──────────────────────────────────
        $display("\n--- Branch Unit: BNE ---");
        funct3 = 3'b001; // BNE

        zero = 0; #1; // not equal → taken
        check({31'b0, branch_taken}, 32'd1, "BNE: zero=0 → taken");

        zero = 1; #1; // equal → not taken
        check({31'b0, branch_taken}, 32'd0, "BNE: zero=1 → not taken");

        // ── BRANCH UNIT: BLT (signed) ─────────────────────────
        $display("\n--- Branch Unit: BLT (signed) ---");
        funct3 = 3'b100; // BLT
        rs1_data = -32'd5; rs2_data = 32'd3; #1; // -5 < 3 → taken
        check({31'b0, branch_taken}, 32'd1, "BLT: -5 < 3 → taken");

        rs1_data = 32'd5; rs2_data = 32'd3; #1;  // 5 > 3 → not taken
        check({31'b0, branch_taken}, 32'd0, "BLT: 5 > 3 → not taken");

        // ── BRANCH UNIT: BLTU (unsigned) ──────────────────────
        $display("\n--- Branch Unit: BLTU (unsigned) ---");
        funct3 = 3'b110; // BLTU
        // 0xFFFFFFFF is huge unsigned, NOT negative
        rs1_data = 32'd1; rs2_data = 32'hFFFFFFFF; #1;
        check({31'b0, branch_taken}, 32'd1, "BLTU: 1 < 0xFFFF unsigned");

        rs1_data = 32'hFFFFFFFF; rs2_data = 32'd1; #1;
        check({31'b0, branch_taken}, 32'd0, "BLTU: 0xFFFF > 1 → not taken");

        // ── BRANCH UNIT: branch=0, no jump ────────────────────
        $display("\n--- Branch Unit: branch=0 ---");
        branch = 0; zero = 1; #1;
        check({31'b0, branch_taken}, 32'd0, "branch=0: never taken");

        // ── BRANCH UNIT: JAL always jumps ─────────────────────
        $display("\n--- Branch Unit: JAL ---");
        branch = 0; jump = 1;
        pc_plus4 = 32'd12; imm = 32'd100; #1; // target = (12-4)+100 = 108
        check({31'b0, branch_taken}, 32'd1,   "JAL: always taken");
        check(branch_target,         32'd108,  "JAL: target = PC+imm");

        // ── Summary ───────────────────────────────────────────
        $display("\n========================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");

        $finish;
    end

endmodule