// ============================================================
//  Testbench — Register File
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Run:
//    iverilog -o sim/rf_sim.vvp rtl/register_file.v tb/tb_register_file.v
//    vvp sim/rf_sim.vvp
//    gtkwave sim/rf_dump.vcd
// ============================================================

`timescale 1ns/1ps

module tb_register_file;

    // ── DUT signals ──────────────────────────────────────────
    reg        clk;
    reg  [4:0] rs1_addr, rs2_addr, rd_addr;
    reg  [31:0] rd_data;
    reg        reg_write;
    wire [31:0] rs1_data, rs2_data;

    // ── Instantiate DUT ──────────────────────────────────────
    register_file uut (
        .clk       (clk),
        .rs1_addr  (rs1_addr),
        .rs2_addr  (rs2_addr),
        .rs1_data  (rs1_data),
        .rs2_data  (rs2_data),
        .rd_addr   (rd_addr),
        .rd_data   (rd_data),
        .reg_write (reg_write)
    );

    // ── Clock: toggles every 5ns → 10ns period (100 MHz) ─────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── VCD dump ─────────────────────────────────────────────
    initial begin
        $dumpfile("sim/rf_dump.vcd");
        $dumpvars(0, tb_register_file);
    end

    // ── Helper task ───────────────────────────────────────────
    integer pass_count, fail_count;

    task check_read;
        input [31:0] actual;
        input [31:0] expected;
        input [80*8:1] test_name;
        begin
            if (actual === expected) begin
                $display("  PASS  %-35s | got=%0d", test_name, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-35s | got=%0d, expected=%0d",
                         test_name, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Main test sequence ────────────────────────────────────
    initial begin
        pass_count = 0; fail_count = 0;
        reg_write = 0;
        rd_addr = 0; rd_data = 0;
        rs1_addr = 0; rs2_addr = 0;

        $display("\n========================================");
        $display("  Register File Testbench Starting...");
        $display("========================================\n");

        // ── TEST 1: x0 is always 0 ───────────────────────────
        $display("--- x0 hardwired to zero ---");
        rs1_addr = 5'd0;
        #1;
        check_read(rs1_data, 32'd0, "read x0 = 0 (no write)");

        // Try writing to x0 — should have no effect
        @(negedge clk);
        rd_addr = 5'd0; rd_data = 32'hDEADBEEF; reg_write = 1;
        @(posedge clk); #1;
        reg_write = 0;
        rs1_addr = 5'd0;
        #1;
        check_read(rs1_data, 32'd0, "write to x0 ignored, still 0");

        // ── TEST 2: Write then read back ──────────────────────
        $display("\n--- Write and Read Back ---");

        @(negedge clk);
        rd_addr = 5'd1; rd_data = 32'd42; reg_write = 1;
        @(posedge clk); #1;
        reg_write = 0;
        rs1_addr = 5'd1;
        #1;
        check_read(rs1_data, 32'd42, "write 42 to x1, read x1");

        @(negedge clk);
        rd_addr = 5'd5; rd_data = 32'd100; reg_write = 1;
        @(posedge clk); #1;
        reg_write = 0;
        rs1_addr = 5'd5;
        #1;
        check_read(rs1_data, 32'd100, "write 100 to x5, read x5");

        @(negedge clk);
        rd_addr = 5'd31; rd_data = 32'hCAFEBABE; reg_write = 1;
        @(posedge clk); #1;
        reg_write = 0;
        rs1_addr = 5'd31;
        #1;
        check_read(rs1_data, 32'hCAFEBABE, "write to x31, read x31");

        // ── TEST 3: Dual read ports same cycle ────────────────
        $display("\n--- Dual Read Ports ---");

        // Write x2 = 200, x3 = 300
        @(negedge clk);
        rd_addr = 5'd2; rd_data = 32'd200; reg_write = 1;
        @(posedge clk); #1;
        @(negedge clk);
        rd_addr = 5'd3; rd_data = 32'd300; reg_write = 1;
        @(posedge clk); #1;
        reg_write = 0;

        // Read both in same cycle
        rs1_addr = 5'd2; rs2_addr = 5'd3;
        #1;
        check_read(rs1_data, 32'd200, "dual read: rs1=x2 → 200");
        check_read(rs2_data, 32'd300, "dual read: rs2=x3 → 300");

        // ── TEST 4: reg_write = 0, value should NOT change ────
        $display("\n--- Write Disabled ---");
        rs1_addr = 5'd1;
        @(negedge clk);
        rd_addr = 5'd1; rd_data = 32'd999; reg_write = 0; // write disabled
        @(posedge clk); #1;
        rs1_addr = 5'd1;
        #1;
        check_read(rs1_data, 32'd42, "reg_write=0: x1 stays 42");

        // ── TEST 5: Overwrite a register ─────────────────────
        $display("\n--- Overwrite Register ---");
        @(negedge clk);
        rd_addr = 5'd1; rd_data = 32'd999; reg_write = 1;
        @(posedge clk); #1;
        reg_write = 0;
        rs1_addr = 5'd1;
        #1;
        check_read(rs1_data, 32'd999, "overwrite x1: now 999");

        // ── Summary ───────────────────────────────────────────
        $display("\n========================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");

        $finish;
    end

endmodule