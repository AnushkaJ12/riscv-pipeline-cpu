// ============================================================
//  Testbench — ALU + ALU Control Unit
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Tests every ALU operation with multiple cases including:
//    - normal values
//    - zero inputs
//    - negative numbers (signed)
//    - overflow edge cases
//    - shift amounts
//  Run:  iverilog -o sim/alu_sim rtl/alu.v rtl/alu_control.v tb/tb_alu.v
//        vvp sim/alu_sim
//        gtkwave sim/alu_dump.vcd
// ============================================================

`timescale 1ns/1ps

module tb_alu;

    // ── DUT signals ──────────────────────────────────────────
    reg  [31:0] a, b;
    reg  [ 3:0] alu_ctrl;
    wire [31:0] result;
    wire        zero;

    // ALU Control signals (for alu_control DUT)
    reg  [1:0] alu_op;
    reg  [2:0] funct3;
    reg        funct7_5;
    reg        is_imm;
    wire [3:0] ctrl_out;

    // ── Instantiate ALU ──────────────────────────────────────
    alu uut_alu (
        .a        (a),
        .b        (b),
        .alu_ctrl (alu_ctrl),
        .result   (result),
        .zero     (zero)
    );

    // ── Instantiate ALU Control Unit ─────────────────────────
    alu_control uut_ctrl (
        .alu_op   (alu_op),
        .funct3   (funct3),
        .funct7_5 (funct7_5),
        .is_imm   (is_imm),
        .alu_ctrl (ctrl_out)
    );

    // ── VCD dump for GTKWave ─────────────────────────────────
    initial begin
        $dumpfile("sim/alu_dump.vcd");
        $dumpvars(0, tb_alu);
    end

    // ── Helper task: check result ─────────────────────────────
    integer pass_count, fail_count;

    task check;
        input [63:0] expected;
        input [80*8:1] test_name;
        begin
            #1; // let combinational logic settle
            if (result === expected[31:0]) begin
                $display("  PASS  %-30s | a=%0d b=%0d → result=%0d",
                         test_name, $signed(a), $signed(b), $signed(result));
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-30s | a=%0d b=%0d → got=%0d, expected=%0d",
                         test_name, $signed(a), $signed(b),
                         $signed(result), $signed(expected));
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Main test sequence ────────────────────────────────────
    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("\n========================================");
        $display("  RISC-V ALU Testbench Starting...");
        $display("========================================\n");

        // ─────────────────────────────────────────
        //  ADD  (4'b0000)
        // ─────────────────────────────────────────
        $display("--- ADD ---");
        alu_ctrl = 4'b0000;

        a = 32'd10;     b = 32'd20;     check(32'd30,          "10 + 20 = 30");
        a = 32'd0;      b = 32'd0;      check(32'd0,           "0 + 0 = 0");
        a = 32'hFFFFFFFF; b = 32'd1;   check(32'd0,           "overflow wrap");
        a = -32'd50;    b = 32'd50;     check(32'd0,           "-50 + 50 = 0");
        a = 32'h7FFFFFFF; b = 32'd1;  check(32'h80000000,    "max+1 overflow");

        // ─────────────────────────────────────────
        //  SUB  (4'b0001)
        // ─────────────────────────────────────────
        $display("\n--- SUB ---");
        alu_ctrl = 4'b0001;

        a = 32'd50;     b = 32'd30;     check(32'd20,          "50 - 30 = 20");
        a = 32'd30;     b = 32'd50;     check(-32'd20,         "30 - 50 = -20");
        a = 32'd0;      b = 32'd0;      check(32'd0,           "0 - 0 = 0");
        a = 32'd100;    b = 32'd100;    check(32'd0,           "same values = 0");

        // ─────────────────────────────────────────
        //  AND  (4'b0010)
        // ─────────────────────────────────────────
        $display("\n--- AND ---");
        alu_ctrl = 4'b0010;

        a = 32'hFF00FF00; b = 32'hF0F0F0F0; check(32'hF000F000, "AND pattern");
        a = 32'hFFFFFFFF; b = 32'h00000000; check(32'h00000000, "AND with 0");
        a = 32'hFFFFFFFF; b = 32'hFFFFFFFF; check(32'hFFFFFFFF, "AND all 1s");

        // ─────────────────────────────────────────
        //  OR   (4'b0011)
        // ─────────────────────────────────────────
        $display("\n--- OR ---");
        alu_ctrl = 4'b0011;

        a = 32'hFF00FF00; b = 32'h00FF00FF; check(32'hFFFFFFFF, "OR complement");
        a = 32'h00000000; b = 32'h00000000; check(32'h00000000, "OR all zeros");
        a = 32'hA0A0A0A0; b = 32'h0F0F0F0F; check(32'hAFAFAFAF, "OR pattern");

        // ─────────────────────────────────────────
        //  XOR  (4'b0100)
        // ─────────────────────────────────────────
        $display("\n--- XOR ---");
        alu_ctrl = 4'b0100;

        a = 32'hFFFFFFFF; b = 32'hFFFFFFFF; check(32'h00000000, "XOR same = 0");
        a = 32'hFFFFFFFF; b = 32'h00000000; check(32'hFFFFFFFF, "XOR with 0");
        a = 32'hA5A5A5A5; b = 32'h5A5A5A5A; check(32'hFFFFFFFF, "XOR checkerboard");

        // ─────────────────────────────────────────
        //  SLL  (4'b0101)
        // ─────────────────────────────────────────
        $display("\n--- SLL (Shift Left Logical) ---");
        alu_ctrl = 4'b0101;

        a = 32'd1;      b = 32'd4;      check(32'd16,          "1 << 4 = 16");
        a = 32'd1;      b = 32'd31;     check(32'h80000000,    "1 << 31");
        a = 32'hFFFFFFFF; b = 32'd1;   check(32'hFFFFFFFE,    "0xFFFF << 1");

        // ─────────────────────────────────────────
        //  SRL  (4'b0110)
        // ─────────────────────────────────────────
        $display("\n--- SRL (Shift Right Logical) ---");
        alu_ctrl = 4'b0110;

        a = 32'd16;     b = 32'd4;      check(32'd1,           "16 >> 4 = 1");
        a = 32'h80000000; b = 32'd1;   check(32'h40000000,    "logical: no sign ext");
        a = 32'hFFFFFFFF; b = 32'd4;   check(32'h0FFFFFFF,    "0xFF >> 4 logical");

        // ─────────────────────────────────────────
        //  SRA  (4'b0111)
        // ─────────────────────────────────────────
        $display("\n--- SRA (Shift Right Arithmetic) ---");
        alu_ctrl = 4'b0111;

        a = 32'h80000000; b = 32'd1;   check(32'hC0000000,    "SRA sign extends");
        a = 32'hFFFFFFFF; b = 32'd4;   check(32'hFFFFFFFF,    "all 1s stays all 1s");
        a = 32'd16;       b = 32'd4;   check(32'd1,            "positive same as SRL");

        // ─────────────────────────────────────────
        //  SLT  (4'b1000)
        // ─────────────────────────────────────────
        $display("\n--- SLT (Set Less Than, signed) ---");
        alu_ctrl = 4'b1000;

        a = 32'd5;      b = 32'd10;    check(32'd1,            "5 < 10 → 1");
        a = 32'd10;     b = 32'd5;     check(32'd0,            "10 < 5 → 0");
        a = -32'd1;     b = 32'd0;     check(32'd1,            "-1 < 0 → 1 (signed)");
        a = 32'd0;      b = 32'd0;     check(32'd0,            "equal → 0");

        // ─────────────────────────────────────────
        //  SLTU (4'b1001)
        // ─────────────────────────────────────────
        $display("\n--- SLTU (Set Less Than, unsigned) ---");
        alu_ctrl = 4'b1001;

        a = 32'd5;        b = 32'd10;       check(32'd1,       "5 < 10 → 1");
        a = 32'hFFFFFFFF; b = 32'd1;        check(32'd0,       "big > 1 unsigned → 0");
        a = 32'd1;        b = 32'hFFFFFFFF; check(32'd1,       "1 < big unsigned → 1");

        // ─────────────────────────────────────────
        //  Zero Flag Tests
        // ─────────────────────────────────────────
        $display("\n--- ZERO FLAG ---");
        alu_ctrl = 4'b0001; // SUB
        a = 32'd42; b = 32'd42;
        #1;
        if (zero === 1'b1)
            $display("  PASS  zero flag when equal            | a=%0d b=%0d zero=%b", a, b, zero);
        else
            $display("  FAIL  zero flag when equal            | expected 1, got %b", zero);

        a = 32'd42; b = 32'd43;
        #1;
        if (zero === 1'b0)
            $display("  PASS  zero flag when unequal          | a=%0d b=%0d zero=%b", a, b, zero);
        else
            $display("  FAIL  zero flag when unequal          | expected 0, got %b", zero);

        // ─────────────────────────────────────────
        //  ALU CONTROL UNIT Tests
        // ─────────────────────────────────────────
        $display("\n--- ALU CONTROL UNIT ---");
        is_imm = 0;

        // Load/Store → ADD
        alu_op = 2'b00; funct3 = 3'bxxx; funct7_5 = 0;
        #1;
        if (ctrl_out === 4'b0000)
            $display("  PASS  alu_op=00 (load/store) → ADD");
        else
            $display("  FAIL  alu_op=00 → expected ADD(0000) got %b", ctrl_out);

        // Branch → SUB
        alu_op = 2'b01; funct3 = 3'bxxx; funct7_5 = 0;
        #1;
        if (ctrl_out === 4'b0001)
            $display("  PASS  alu_op=01 (branch)     → SUB");
        else
            $display("  FAIL  alu_op=01 → expected SUB(0001) got %b", ctrl_out);

        // R-type ADD
        alu_op = 2'b10; funct3 = 3'b000; funct7_5 = 0; is_imm = 0;
        #1;
        if (ctrl_out === 4'b0000)
            $display("  PASS  R-type funct3=000 f7=0 → ADD");
        else
            $display("  FAIL  R-type ADD → got %b", ctrl_out);

        // R-type SUB
        alu_op = 2'b10; funct3 = 3'b000; funct7_5 = 1; is_imm = 0;
        #1;
        if (ctrl_out === 4'b0001)
            $display("  PASS  R-type funct3=000 f7=1 → SUB");
        else
            $display("  FAIL  R-type SUB → got %b", ctrl_out);

        // I-type ADDI (funct7_5=1 but is_imm=1 → should still be ADD)
        alu_op = 2'b10; funct3 = 3'b000; funct7_5 = 1; is_imm = 1;
        #1;
        if (ctrl_out === 4'b0000)
            $display("  PASS  I-type ADDI (f7=1 ignored) → ADD");
        else
            $display("  FAIL  I-type ADDI → expected ADD got %b", ctrl_out);

        // ─────────────────────────────────────────
        //  Summary
        // ─────────────────────────────────────────
        $display("\n========================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");

        $finish;
    end

endmodule