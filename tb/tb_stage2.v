// ============================================================
//  Testbench — Control Unit + Immediate Gen + IF/ID Register
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Run:
//    iverilog -o sim/stage2_sim.vvp rtl/control_unit.v rtl/immediate_gen.v rtl/IF_ID_reg.v tb/tb_stage2.v
//    vvp sim/stage2_sim.vvp
// ============================================================

`timescale 1ns/1ps

module tb_stage2;

    integer pass_count, fail_count;

    // ── Clock ─────────────────────────────────────────────────
    reg clk, reset;
    initial clk = 0;
    always #5 clk = ~clk;

    // ── VCD dump ──────────────────────────────────────────────
    initial begin
        $dumpfile("sim/stage2_dump.vcd");
        $dumpvars(0, tb_stage2);
    end

    // ── Helper tasks ──────────────────────────────────────────
    task check_bit;
        input actual;
        input expected;
        input [80*8:1] name;
        begin
            if (actual === expected) begin
                $display("  PASS  %-35s | got=%b", name, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-35s | got=%b expected=%b", name, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_val;
        input [31:0] actual;
        input [31:0] expected;
        input [80*8:1] name;
        begin
            if (actual === expected) begin
                $display("  PASS  %-35s | got=0x%08h", name, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-35s | got=0x%08h exp=0x%08h", name, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ═══════════════════════════════════════════════════════════
    //  CONTROL UNIT TESTS
    // ═══════════════════════════════════════════════════════════
    reg  [6:0] opcode;
    wire       reg_write, mem_read, mem_write, mem_to_reg;
    wire       alu_src, branch, jump;
    wire [1:0] alu_op;

    control_unit uut_cu (
        .opcode     (opcode),
        .reg_write  (reg_write),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .mem_to_reg (mem_to_reg),
        .alu_src    (alu_src),
        .branch     (branch),
        .jump       (jump),
        .alu_op     (alu_op)
    );

    // ═══════════════════════════════════════════════════════════
    //  IMMEDIATE GEN TESTS
    // ═══════════════════════════════════════════════════════════
    reg  [31:0] instruction_imm;
    wire [31:0] imm_out;

    immediate_gen uut_imm (
        .instruction (instruction_imm),
        .imm_out     (imm_out)
    );

    // ═══════════════════════════════════════════════════════════
    //  IF/ID REGISTER TESTS
    // ═══════════════════════════════════════════════════════════
    reg        stall, flush;
    reg [31:0] if_pc_plus4, if_instruction;
    wire[31:0] id_pc_plus4, id_instruction;

    IF_ID_reg uut_ifid (
        .clk           (clk),
        .reset         (reset),
        .stall         (stall),
        .flush         (flush),
        .if_pc_plus4   (if_pc_plus4),
        .if_instruction(if_instruction),
        .id_pc_plus4   (id_pc_plus4),
        .id_instruction(id_instruction)
    );

    // ═══════════════════════════════════════════════════════════
    //  MAIN TEST
    // ═══════════════════════════════════════════════════════════
    initial begin
        pass_count = 0; fail_count = 0;
        reset = 1; stall = 0; flush = 0;
        if_pc_plus4 = 0; if_instruction = 0;

        $display("\n========================================");
        $display("  Stage 2 Modules Testbench");
        $display("========================================");

        // ── CONTROL UNIT ──────────────────────────────────────
        $display("\n--- Control Unit: R-type (add/sub) ---");
        opcode = 7'b0110011; #1;
        check_bit(reg_write,  1, "R-type: reg_write=1");
        check_bit(alu_src,    0, "R-type: alu_src=0 (use rs2)");
        check_bit(mem_read,   0, "R-type: mem_read=0");
        check_bit(mem_write,  0, "R-type: mem_write=0");
        check_bit(branch,     0, "R-type: branch=0");

        $display("\n--- Control Unit: I-type (addi) ---");
        opcode = 7'b0010011; #1;
        check_bit(reg_write,  1, "I-type: reg_write=1");
        check_bit(alu_src,    1, "I-type: alu_src=1 (use imm)");
        check_bit(mem_read,   0, "I-type: mem_read=0");

        $display("\n--- Control Unit: Load (lw) ---");
        opcode = 7'b0000011; #1;
        check_bit(reg_write,  1, "lw: reg_write=1");
        check_bit(mem_read,   1, "lw: mem_read=1");
        check_bit(mem_to_reg, 1, "lw: mem_to_reg=1");
        check_bit(alu_src,    1, "lw: alu_src=1 (rs1+imm)");

        $display("\n--- Control Unit: Store (sw) ---");
        opcode = 7'b0100011; #1;
        check_bit(reg_write,  0, "sw: reg_write=0");
        check_bit(mem_write,  1, "sw: mem_write=1");
        check_bit(alu_src,    1, "sw: alu_src=1");

        $display("\n--- Control Unit: Branch (beq) ---");
        opcode = 7'b1100011; #1;
        check_bit(branch,     1, "beq: branch=1");
        check_bit(reg_write,  0, "beq: reg_write=0");
        check_bit(alu_src,    0, "beq: alu_src=0 (compare regs)");

        // ── IMMEDIATE GEN ─────────────────────────────────────
        $display("\n--- Immediate Gen: I-type addi x1,x0,5 ---");
        // addi x1, x0, 5 = 0x00500093
        // imm = bits[31:20] = 0x005 = 5
        instruction_imm = 32'h00500093; #1;
        check_val(imm_out, 32'd5, "addi imm = 5");

        $display("\n--- Immediate Gen: I-type addi x2,x0,-1 ---");
        // addi x2, x0, -1 → imm[11:0] = 0xFFF → sign extend → 0xFFFFFFFF
        instruction_imm = 32'hFFF00113; #1;
        check_val(imm_out, 32'hFFFFFFFF, "addi imm = -1 sign extended");

        $display("\n--- Immediate Gen: S-type sw ---");
        // sw x1, 8(x0) → imm = 8 = 0x008
        // imm[11:5]=0000000, imm[4:0]=01000 → stored split in instruction
        instruction_imm = 32'h00102423; #1;
        check_val(imm_out, 32'd8, "sw imm = 8");

        $display("\n--- Immediate Gen: U-type lui ---");
        // lui x1, 0x12345 → imm = 0x12345000
        instruction_imm = 32'h123450B7; #1;
        check_val(imm_out, 32'h12345000, "lui imm = 0x12345000");

        // ── IF/ID REGISTER ────────────────────────────────────
        $display("\n--- IF/ID Register: Normal Latch ---");
        @(posedge clk); #1; reset = 0;
        if_pc_plus4    = 32'd8;
        if_instruction = 32'h00500093;
        @(posedge clk); #1;
        check_val(id_pc_plus4,    32'd8,         "IF/ID: pc_plus4 latched");
        check_val(id_instruction, 32'h00500093,  "IF/ID: instruction latched");

        $display("\n--- IF/ID Register: Stall (freeze) ---");
        if_pc_plus4    = 32'd99;       // new values arrive
        if_instruction = 32'hDEADBEEF;
        stall = 1;
        @(posedge clk); #1;
        check_val(id_pc_plus4,    32'd8,        "IF/ID stall: pc held");
        check_val(id_instruction, 32'h00500093, "IF/ID stall: instr held");
        stall = 0;

        $display("\n--- IF/ID Register: Flush (NOP bubble) ---");
        flush = 1;
        @(posedge clk); #1;
        flush = 0;
        check_val(id_instruction, 32'h00000013, "IF/ID flush: NOP inserted");

        $display("\n--- IF/ID Register: Reset ---");
        reset = 1;
        @(posedge clk); #1;
        reset = 0; #1;
        check_val(id_instruction, 32'h00000013, "IF/ID reset: NOP");

        // ── Summary ───────────────────────────────────────────
        $display("\n========================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");

        $finish;
    end

endmodule