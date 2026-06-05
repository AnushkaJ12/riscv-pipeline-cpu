// ============================================================
//  Testbench — Instruction Memory + PC Register
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Run:
//    iverilog -o sim/imem_sim.vvp rtl/pc_register.v rtl/instruction_memory.v tb/tb_instruction_memory.v
//    vvp sim/imem_sim.vvp
//    gtkwave sim/imem_dump.vcd
// ============================================================

`timescale 1ns/1ps

module tb_instruction_memory;

    // ── DUT signals ──────────────────────────────────────────
    reg        clk, reset, stall, branch_taken;
    reg [31:0] branch_target;
    wire[31:0] pc_out, pc_plus4, instruction;

    // ── Instantiate PC ────────────────────────────────────────
    pc_register uut_pc (
        .clk          (clk),
        .reset        (reset),
        .stall        (stall),
        .branch_taken (branch_taken),
        .branch_target(branch_target),
        .pc_out       (pc_out),
        .pc_plus4     (pc_plus4)
    );

    // ── Instantiate Instruction Memory ────────────────────────
    instruction_memory uut_imem (
        .pc          (pc_out),
        .instruction (instruction)
    );

    // ── Clock ─────────────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── VCD dump ──────────────────────────────────────────────
    initial begin
        $dumpfile("sim/imem_dump.vcd");
        $dumpvars(0, tb_instruction_memory);
    end

    // ── Helper task ───────────────────────────────────────────
    integer pass_count, fail_count;

    task check;
        input [31:0] actual;
        input [31:0] expected;
        input [80*8:1] test_name;
        begin
            if (actual === expected) begin
                $display("  PASS  %-35s | got=0x%08h", test_name, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-35s | got=0x%08h expected=0x%08h",
                         test_name, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Main test ─────────────────────────────────────────────
    initial begin
        pass_count = 0; fail_count = 0;
        reset = 1; stall = 0; branch_taken = 0; branch_target = 0;

        $display("\n========================================");
        $display("  Instruction Memory Testbench");
        $display("========================================\n");

        // Apply reset for 2 cycles
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;

        // ── TEST 1: PC starts at 0 after reset ────────────────
        $display("--- PC Reset & Sequential Fetch ---");
        check(pc_out, 32'd0, "PC=0 after reset");
        check(instruction, 32'h00500093, "instr[0]: addi x1,x0,5");

        // ── TEST 2: PC advances by 4 each cycle ───────────────
        @(posedge clk); #1;
        check(pc_out,    32'd4,         "PC=4 after 1 cycle");
        check(pc_plus4,  32'd8,         "PC+4=8");
        check(instruction, 32'h00A00113, "instr[1]: addi x2,x0,10");

        @(posedge clk); #1;
        check(pc_out, 32'd8,            "PC=8 after 2 cycles");
        check(instruction, 32'h00208133, "instr[2]: add x3,x1,x2");

        @(posedge clk); #1;
        check(pc_out, 32'd12,           "PC=12 after 3 cycles");
        check(instruction, 32'h402081B3, "instr[3]: sub x4,x2,x1");

        // ── TEST 3: Stall — PC should freeze ──────────────────
        $display("\n--- Stall (PC Freeze) ---");
        stall = 1;
        @(posedge clk); #1;
        check(pc_out, 32'd12, "PC stays 12 during stall");

        @(posedge clk); #1;
        check(pc_out, 32'd12, "PC still 12, stall cycle 2");

        stall = 0;
        @(posedge clk); #1;
        check(pc_out, 32'd16, "PC resumes to 16 after stall");

        // ── TEST 4: Branch taken ───────────────────────────────
        $display("\n--- Branch Taken ---");
        branch_target = 32'd8;   // jump back to instruction 2
        branch_taken  = 1;
        @(posedge clk); #1;
        branch_taken = 0;
        check(pc_out, 32'd8,  "PC jumped to branch target 8");
        check(instruction, 32'h00208133, "fetching instr at addr 8 again");

        // ── TEST 5: Reset mid-execution ───────────────────────
        $display("\n--- Reset Mid-Execution ---");
        @(posedge clk); #1;
        reset = 1;
        @(posedge clk); #1;
        reset = 0;
        #1;
        check(pc_out, 32'd0, "PC back to 0 after mid reset");

        // ── Summary ───────────────────────────────────────────
        $display("\n========================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");

        $finish;
    end

endmodule