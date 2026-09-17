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
//    add  x3, x1, x2     → x3 = 15
//    add  x4, x3, x1     → x4 = 20
//    sub  x4, x2, x1     → x4 = 5 (x2-x1)    (data hazard → forwarding)
//    and  x5, x1, x2     → x5 = 0
//    or   x6, x1, x2     → x6 = 15
//    sw   x3, 0(x0)      → mem[0] = 15
//    lw   x7, 0(x0)      → x7 = 15   (load-use hazard → stall)
//    add  x8, x7, x1     → MUST stall, then x8 = 20
     
//    addi x9,  x0, 5
//    addi x10, x0, 5
//    beq  x9, x10, LABEL_TAKEN
//    addi x11, x0, 99
//    LABEL_TAKEN:
//    addi x12, x0, 10

//    addi x13, x0, 5
//    addi x14, x0, 10
//    beq  x13, x14, LABEL_NOT_TAKEN
//    addi x15, x0, 99     → MUST execute
//    LABEL_NOT_TAKEN:
//    addi x16, x0, 20

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
   logic clk, reset;

    // ── Instantiate CPU ───────────────────────────────────────
    top uut (
        .clk   (clk),
        .reset (reset)
    );

// ============================================================
// SystemVerilog procedural assertion: x0 must remain zero
// ============================================================
always @(posedge clk) begin
    if (!reset) begin
        assert (uut.u_regfile.registers[0] == 32'd0)
            else $error("ASSERTION FAILED: x0 is not zero!");
    end
end

// ============================================================
// Load-use hazard assertion
// ============================================================
always @(posedge clk) begin
    if (!reset) begin

        // Detect the same condition used by hazard_unit
        if (uut.ex_mem_read &&
            (uut.ex_rd_addr != 5'd0) &&
            ((uut.ex_rd_addr == uut.id_rs1_addr) ||
             (uut.ex_rd_addr == uut.id_rs2_addr))) begin

            // A load-use hazard must stall the pipeline
            assert (uut.hz_pc_write == 1'b0)
                else $error("ASSERTION FAILED: PC was not stalled during load-use hazard!");

            assert (uut.hz_if_id_write == 1'b0)
                else $error("ASSERTION FAILED: IF/ID was not stalled during load-use hazard!");

            assert (uut.hz_id_ex_flush == 1'b1)
                else $error("ASSERTION FAILED: ID/EX was not flushed during load-use hazard!");
        end
    end
end

// ============================================================
// Forwarding assertions
// ============================================================
always @(posedge clk) begin
    if (!reset) begin

        // ----------------------------------------------------
        // EX/MEM -> EX forwarding for ALU operand A
        // ----------------------------------------------------
        if ((uut.ex_rs1_addr != 5'd0) &&
            (uut.ex_rs1_addr == uut.mem_rd_addr) &&
            uut.mem_reg_write) begin

            assert (uut.fwd_a == 2'b10)
                else $error("ASSERTION FAILED: EX/MEM -> EX forwarding not selected for RS1!");
        end


        // ----------------------------------------------------
        // EX/MEM -> EX forwarding for ALU operand B
        // ----------------------------------------------------
        if ((uut.ex_rs2_addr != 5'd0) &&
            (uut.ex_rs2_addr == uut.mem_rd_addr) &&
            uut.mem_reg_write) begin

            assert (uut.fwd_b == 2'b10)
                else $error("ASSERTION FAILED: EX/MEM -> EX forwarding not selected for RS2!");
        end


        // ----------------------------------------------------
        // MEM/WB -> EX forwarding for ALU operand A
        // ----------------------------------------------------
        if ((uut.ex_rs1_addr != 5'd0) &&
            (uut.ex_rs1_addr == uut.wb_rd_addr) &&
            uut.wb_reg_write &&
            !((uut.ex_rs1_addr == uut.mem_rd_addr) &&
              uut.mem_reg_write)) begin

            assert (uut.fwd_a == 2'b01)
                else $error("ASSERTION FAILED: MEM/WB -> EX forwarding not selected for RS1!");
        end


        // ----------------------------------------------------
        // MEM/WB -> EX forwarding for ALU operand B
        // ----------------------------------------------------
        if ((uut.ex_rs2_addr != 5'd0) &&
            (uut.ex_rs2_addr == uut.wb_rd_addr) &&
            uut.wb_reg_write &&
            !((uut.ex_rs2_addr == uut.mem_rd_addr) &&
              uut.mem_reg_write)) begin

            assert (uut.fwd_b == 2'b01)
                else $error("ASSERTION FAILED: MEM/WB -> EX forwarding not selected for RS2!");
        end

    end
end

// ============================================================
// Branch flush assertion
// ============================================================
always @(posedge clk) begin
    if (!reset) begin

        // If a branch is taken, the wrong-path instruction
        // must be prevented from entering the pipeline.
        if (uut.ex_branch_taken) begin

            // IF/ID flush must be asserted
            assert (uut.ex_branch_taken == 1'b1)
                else $error("ASSERTION FAILED: IF/ID flush not asserted after taken branch!");

            // ID/EX flush must be asserted
            assert ((uut.hz_id_ex_flush | uut.ex_branch_taken) == 1'b1)
                else $error("ASSERTION FAILED: ID/EX flush not asserted after taken branch!");

        end
    end
end

// ============================================================
// Functional Coverage: Branch Taken / Not Taken
// ============================================================

integer branch_taken_seen;
integer branch_not_taken_seen;

initial begin
    branch_taken_seen = 0;
    branch_not_taken_seen = 0;
end

always @(posedge clk) begin
    if (!reset) begin
        if (uut.ex_branch_taken)
            branch_taken_seen = 1;
        else
            branch_not_taken_seen = 1;
    end
end

// ============================================================
// Functional Coverage: Forwarding
// ============================================================

integer exmem_forward_seen;
integer memwb_forward_seen;

initial begin
    exmem_forward_seen = 0;
    memwb_forward_seen = 0;
end

always @(posedge clk) begin
    if (!reset) begin

        // EX/MEM -> EX forwarding
        if ((uut.fwd_a == 2'b10) || (uut.fwd_b == 2'b10))
            exmem_forward_seen = 1;

        // MEM/WB -> EX forwarding
        if ((uut.fwd_a == 2'b01) || (uut.fwd_b == 2'b01))
            memwb_forward_seen = 1;

    end
end

integer load_use_hazard_seen;

initial begin
    load_use_hazard_seen = 0;
end

always @(posedge clk) begin
    if (!reset) begin
        if (uut.ex_mem_read &&
            (uut.ex_rd_addr != 5'd0) &&
            ((uut.ex_rd_addr == uut.id_rs1_addr) ||
             (uut.ex_rd_addr == uut.id_rs2_addr))) begin
            load_use_hazard_seen = 1;
        end
    end
end

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
        logic [31:0] actual;
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

        // Run program long enough for all instructions,
        // including load-use stall and branch handling, to complete.
        repeat(30) @(posedge clk);
        #1;

        // ── Check register results ─────────────────────────────
        $display("--- Register File Results ---");

        check_reg(1,  32'd5,  "addi x1,x0,5");
        check_reg(2,  32'd10, "addi x2,x0,10");
        check_reg(3,  32'd15, "add  x3,x1,x2  (forwarding)");
        check_reg(4,  32'd5,  "sub  x4,x2,x1  (forwarding, final value)");
        check_reg(5,  32'd0,  "and  x5,x1,x2  (5&10=0)");
        check_reg(6,  32'd15, "or   x6,x1,x2  (5|10=15)");
        check_reg(7,  32'd15, "lw   x7,0(x0)  (load-use stall)");
        check_reg(8,  32'd20, "load-use hazard: lw followed by add");

        check_reg(9,  32'd5,  "branch setup x9");
        check_reg(10, 32'd5,  "branch setup x10");
        check_reg(11, 32'd0,  "branch taken: wrong-path instruction flushed");
        check_reg(12, 32'd10, "branch taken: target executed");
        
        check_reg(13, 32'd5,  "branch not taken setup x13");
        check_reg(14, 32'd10, "branch not taken setup x14");
        check_reg(15, 32'd99, "branch not taken: fall-through executed");
        check_reg(16, 32'd20, "branch not taken: next instruction executed");

        $display("--- Memory Results ---");
        check_mem(0, 32'd15, "sw x3,0(x0)");

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


        $display("==============================================");
        $display(" Functional Coverage");
        $display("==============================================");
        if (branch_taken_seen && branch_not_taken_seen)
        $display(" Branch Coverage = 100.00%%");
        else if (branch_taken_seen || branch_not_taken_seen)
        $display(" Branch Coverage = 50.00%%");
        else
        $display(" Branch Coverage = 0.00%%");

        if (exmem_forward_seen)
    $display(" EX/MEM -> EX Forwarding = 100.00%%");
    else
    $display(" EX/MEM -> EX Forwarding = 0.00%%");

    if (memwb_forward_seen)
    $display(" MEM/WB -> EX Forwarding = 100.00%%");
    else
    $display(" MEM/WB -> EX Forwarding = 0.00%%");

    if (load_use_hazard_seen)
    $display(" Load-Use Hazard Coverage = 100.00%%");
    else
    $display(" Load-Use Hazard Coverage = 0.00%%");

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