// ============================================================
//  Testbench — Full 5-Stage Pipelined RISC-V CPU
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  This runs a real RISC-V program and checks register values
//  after execution to verify the full pipeline is correct.
//
//  Program (program.hex):
//    addi x1, x0, 5      → x1 = 5
//    addi x2, x0, 10     → x2 = 10
//    add  x3, x1, x2     → x3 = 15   (data hazard → forwarding)
//    sub  x4, x2, x1     → x4 = 5    (data hazard → forwarding)
//    and  x5, x1, x2     → x5 = 0
//    or   x6, x1, x2     → x6 = 15
//    sw   x3, 0(x0)      → mem[0] = 15
//    lw   x7, 0(x0)      → x7 = 15   (load-use hazard → stall)
//
//  Run:
//    iverilog -o sim/cpu_sim.vvp rtl/top.v rtl/alu.v rtl/alu_control.v
//      rtl/register_file.v rtl/instruction_memory.v rtl/pc_register.v
//      rtl/control_unit.v rtl/immediate_gen.v rtl/IF_ID_reg.v
//      rtl/ID_EX_reg.v rtl/EX_MEM_reg.v rtl/MEM_WB_reg.v
//      rtl/data_memory.v rtl/branch_unit.v rtl/forwarding_unit.v
//      rtl/hazard_unit.v tb/tb_top.v
//    vvp sim/cpu_sim.vvp
//    gtkwave sim/cpu_dump.vcd
// ============================================================

`timescale 1ns/1ps

module tb_top;

    // ── DUT signals ──────────────────────────────────────────
    reg clk, reset;

    // ── Instantiate CPU ───────────────────────────────────────
    top uut (
        .clk   (clk),
        .reset (reset)
    );

    // ── Clock: 10ns period ────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── VCD dump for GTKWave ──────────────────────────────────
    initial begin
        $dumpfile("sim/cpu_dump.vcd");
        $dumpvars(0, tb_top);
    end

    // ── Helper task ───────────────────────────────────────────
    integer pass_count, fail_count;

    task check_reg;
        input [4:0]  reg_addr;
        input [31:0] expected;
        input [80*8:1] name;
        reg [31:0] actual;
        begin
            actual = uut.u_regfile.registers[reg_addr];
            if (actual === expected) begin
                $display("  PASS  %-30s | x%0d = %0d", name, reg_addr, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-30s | x%0d = %0d, expected %0d",
                         name, reg_addr, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_mem;
        input [7:0]  addr_word;   // word address
        input [31:0] expected;
        input [80*8:1] name;
        reg [31:0] actual;
        begin
            actual = uut.u_dmem.mem[addr_word];
            if (actual === expected) begin
                $display("  PASS  %-30s | mem[%0d] = %0d", name, addr_word, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-30s | mem[%0d] = %0d, expected %0d",
                         name, addr_word, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Main test ─────────────────────────────────────────────
    initial begin
        pass_count = 0; fail_count = 0;
        reset = 1;

        $display("\n================================================");
        $display("  RISC-V 5-Stage Pipeline CPU — Full Test");
        $display("================================================\n");

        // Hold reset for 2 cycles
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;

        $display("Running program...\n");

        // Run for 20 cycles — enough for all 8 instructions
        // to complete including stalls from load-use hazard
        repeat(20) @(posedge clk);
        #1;

        // ── Check register results ─────────────────────────────
        $display("--- Register File Results ---");
        check_reg(1, 32'd5,  "addi x1,x0,5");
        check_reg(2, 32'd10, "addi x2,x0,10");
        check_reg(3, 32'd15, "add  x3,x1,x2  (forwarding)");
        check_reg(4, 32'd5,  "sub  x4,x2,x1  (forwarding)");
        check_reg(5, 32'd0,  "and  x5,x1,x2  (5&10=0)");
        check_reg(6, 32'd15, "or   x6,x1,x2  (5|10=15)");
        check_reg(7, 32'd15, "lw   x7,0(x0)  (load-use stall)");

        // ── Check memory ──────────────────────────────────────
        $display("\n--- Data Memory Results ---");
        check_mem(0, 32'd15, "sw x3,0(x0) stored 15");

        // ── Check x0 always 0 ─────────────────────────────────
        $display("\n--- Sanity Checks ---");
        check_reg(0, 32'd0,  "x0 always zero");

        // ── Summary ───────────────────────────────────────────
        $display("\n================================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED — CPU is working! 🎉");
        else
            $display("  Some tests failed — check waveforms");
        $display("================================================\n");

        $finish;
    end

    // ── Live pipeline monitor (prints every cycle) ────────────
    // Uncomment to see instruction flow cycle by cycle
    /*
    always @(posedge clk) begin
        if (!reset) begin
            $display("Cycle %0d | PC=%0d | IF_instr=0x%08h | ID_instr=0x%08h",
                $time/10,
                uut.if_pc,
                uut.if_instruction,
                uut.id_instruction);
        end
    end
    */

endmodule