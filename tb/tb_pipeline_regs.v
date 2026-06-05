//  Testbench — ID/EX, EX/MEM, MEM/WB Pipeline Registers
//  RISC-V 5-Stage Pipeline CPU
// ============================================================
//  Run:
//    iverilog -o sim/pregs_sim.vvp rtl/ID_EX_reg.v rtl/EX_MEM_reg.v rtl/MEM_WB_reg.v tb/tb_pipeline_regs.v
//    vvp sim/pregs_sim.vvp
// ============================================================

`timescale 1ns/1ps

module tb_pipeline_regs;

    integer pass_count, fail_count;

    reg clk, reset;
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/pregs_dump.vcd");
        $dumpvars(0, tb_pipeline_regs);
    end

    task check;
        input [31:0] actual;
        input [31:0] expected;
        input [80*8:1] name;
        begin
            if (actual === expected) begin
                $display("  PASS  %-40s | got=0x%08h", name, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-40s | got=0x%08h exp=0x%08h",
                         name, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ═══════════════════════════════════════════════════════════
    //  ID/EX Register signals
    // ═══════════════════════════════════════════════════════════
    reg        idex_flush;
    reg        id_reg_write, id_mem_read, id_mem_write;
    reg        id_mem_to_reg, id_alu_src, id_branch, id_jump;
    reg [1:0]  id_alu_op;
    reg [31:0] id_pc_plus4, id_rs1_data, id_rs2_data, id_imm;
    reg [4:0]  id_rs1_addr, id_rs2_addr, id_rd_addr;
    reg [2:0]  id_funct3;
    reg        id_funct7_5;

    wire       ex_reg_write_o, ex_mem_read_o, ex_mem_write_o;
    wire       ex_mem_to_reg_o, ex_alu_src_o, ex_branch_o, ex_jump_o;
    wire[1:0]  ex_alu_op_o;
    wire[31:0] ex_pc_plus4_o, ex_rs1_data_o, ex_rs2_data_o, ex_imm_o;
    wire[4:0]  ex_rs1_addr_o, ex_rs2_addr_o, ex_rd_addr_o;
    wire[2:0]  ex_funct3_o;
    wire       ex_funct7_5_o;

    ID_EX_reg uut_idex (
        .clk(clk), .reset(reset), .flush(idex_flush),
        .id_reg_write(id_reg_write), .id_mem_read(id_mem_read),
        .id_mem_write(id_mem_write), .id_mem_to_reg(id_mem_to_reg),
        .id_alu_src(id_alu_src), .id_branch(id_branch),
        .id_jump(id_jump), .id_alu_op(id_alu_op),
        .id_pc_plus4(id_pc_plus4), .id_rs1_data(id_rs1_data),
        .id_rs2_data(id_rs2_data), .id_imm(id_imm),
        .id_rs1_addr(id_rs1_addr), .id_rs2_addr(id_rs2_addr),
        .id_rd_addr(id_rd_addr), .id_funct3(id_funct3),
        .id_funct7_5(id_funct7_5),
        .ex_reg_write(ex_reg_write_o), .ex_mem_read(ex_mem_read_o),
        .ex_mem_write(ex_mem_write_o), .ex_mem_to_reg(ex_mem_to_reg_o),
        .ex_alu_src(ex_alu_src_o), .ex_branch(ex_branch_o),
        .ex_jump(ex_jump_o), .ex_alu_op(ex_alu_op_o),
        .ex_pc_plus4(ex_pc_plus4_o), .ex_rs1_data(ex_rs1_data_o),
        .ex_rs2_data(ex_rs2_data_o), .ex_imm(ex_imm_o),
        .ex_rs1_addr(ex_rs1_addr_o), .ex_rs2_addr(ex_rs2_addr_o),
        .ex_rd_addr(ex_rd_addr_o), .ex_funct3(ex_funct3_o),
        .ex_funct7_5(ex_funct7_5_o)
    );

    // ═══════════════════════════════════════════════════════════
    //  EX/MEM Register signals
    // ═══════════════════════════════════════════════════════════
    reg        ex_reg_write_i, ex_mem_read_i, ex_mem_write_i;
    reg        ex_mem_to_reg_i, ex_branch_i, ex_jump_i;
    reg [31:0] ex_alu_result_i, ex_rs2_data_i, ex_pc_plus4_i;
    reg [31:0] ex_branch_target_i;
    reg        ex_zero_i;
    reg [4:0]  ex_rd_addr_i;

    wire       mem_reg_write_o, mem_mem_read_o, mem_mem_write_o;
    wire       mem_mem_to_reg_o, mem_branch_o, mem_jump_o;
    wire[31:0] mem_alu_result_o, mem_rs2_data_o, mem_pc_plus4_o;
    wire[31:0] mem_branch_target_o;
    wire       mem_zero_o;
    wire[4:0]  mem_rd_addr_o;

    EX_MEM_reg uut_exmem (
        .clk(clk), .reset(reset),
        .ex_reg_write(ex_reg_write_i), .ex_mem_read(ex_mem_read_i),
        .ex_mem_write(ex_mem_write_i), .ex_mem_to_reg(ex_mem_to_reg_i),
        .ex_branch(ex_branch_i), .ex_jump(ex_jump_i),
        .ex_alu_result(ex_alu_result_i), .ex_zero(ex_zero_i),
        .ex_rs2_data(ex_rs2_data_i), .ex_rd_addr(ex_rd_addr_i),
        .ex_pc_plus4(ex_pc_plus4_i), .ex_branch_target(ex_branch_target_i),
        .mem_reg_write(mem_reg_write_o), .mem_mem_read(mem_mem_read_o),
        .mem_mem_write(mem_mem_write_o), .mem_mem_to_reg(mem_mem_to_reg_o),
        .mem_branch(mem_branch_o), .mem_jump(mem_jump_o),
        .mem_alu_result(mem_alu_result_o), .mem_zero(mem_zero_o),
        .mem_rs2_data(mem_rs2_data_o), .mem_rd_addr(mem_rd_addr_o),
        .mem_pc_plus4(mem_pc_plus4_o), .mem_branch_target(mem_branch_target_o)
    );

    // ═══════════════════════════════════════════════════════════
    //  MEM/WB Register signals
    // ═══════════════════════════════════════════════════════════
    reg        mem_reg_write_i, mem_mem_to_reg_i;
    reg [31:0] mem_read_data_i, mem_alu_result_i, mem_pc_plus4_i;
    reg [4:0]  mem_rd_addr_i;

    wire       wb_reg_write_o, wb_mem_to_reg_o;
    wire[31:0] wb_read_data_o, wb_alu_result_o, wb_pc_plus4_o;
    wire[4:0]  wb_rd_addr_o;

    MEM_WB_reg uut_memwb (
        .clk(clk), .reset(reset),
        .mem_reg_write(mem_reg_write_i), .mem_mem_to_reg(mem_mem_to_reg_i),
        .mem_read_data(mem_read_data_i), .mem_alu_result(mem_alu_result_i),
        .mem_rd_addr(mem_rd_addr_i), .mem_pc_plus4(mem_pc_plus4_i),
        .wb_reg_write(wb_reg_write_o), .wb_mem_to_reg(wb_mem_to_reg_o),
        .wb_read_data(wb_read_data_o), .wb_alu_result(wb_alu_result_o),
        .wb_rd_addr(wb_rd_addr_o), .wb_pc_plus4(wb_pc_plus4_o)
    );

    // ═══════════════════════════════════════════════════════════
    //  MAIN TEST
    // ═══════════════════════════════════════════════════════════
    initial begin
        pass_count = 0; fail_count = 0;
        reset = 1; idex_flush = 0;

        // init all inputs to 0
        {id_reg_write,id_mem_read,id_mem_write,id_mem_to_reg,
         id_alu_src,id_branch,id_jump} = 0;
        id_alu_op = 0; id_pc_plus4 = 0; id_rs1_data = 0;
        id_rs2_data = 0; id_imm = 0; id_rs1_addr = 0;
        id_rs2_addr = 0; id_rd_addr = 0; id_funct3 = 0; id_funct7_5 = 0;

        {ex_reg_write_i,ex_mem_read_i,ex_mem_write_i,
         ex_mem_to_reg_i,ex_branch_i,ex_jump_i} = 0;
        ex_alu_result_i = 0; ex_zero_i = 0; ex_rs2_data_i = 0;
        ex_rd_addr_i = 0; ex_pc_plus4_i = 0; ex_branch_target_i = 0;

        {mem_reg_write_i,mem_mem_to_reg_i} = 0;
        mem_read_data_i = 0; mem_alu_result_i = 0;
        mem_rd_addr_i = 0; mem_pc_plus4_i = 0;

        $display("\n========================================");
        $display("  Pipeline Registers Testbench");
        $display("========================================");

        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;

        // ── TEST ID/EX: Normal latch ───────────────────────────
        $display("\n--- ID/EX Register: Normal Latch ---");
        id_reg_write = 1; id_alu_src = 1; id_alu_op = 2'b10;
        id_rs1_data  = 32'd42; id_rs2_data = 32'd99;
        id_imm       = 32'd5;  id_rd_addr  = 5'd3;
        id_pc_plus4  = 32'd8;

        @(posedge clk); #1;
        check(ex_rs1_data_o,  32'd42, "ID/EX: rs1_data latched");
        check(ex_rs2_data_o,  32'd99, "ID/EX: rs2_data latched");
        check(ex_imm_o,       32'd5,  "ID/EX: imm latched");
        check(ex_rd_addr_o,   32'd3,  "ID/EX: rd_addr latched");
        check(ex_pc_plus4_o,  32'd8,  "ID/EX: pc_plus4 latched");
        check({31'b0,ex_reg_write_o}, 32'd1, "ID/EX: reg_write=1");
        check({31'b0,ex_alu_src_o},   32'd1, "ID/EX: alu_src=1");

        // ── TEST ID/EX: Flush ─────────────────────────────────
        $display("\n--- ID/EX Register: Flush ---");
        idex_flush = 1;
        @(posedge clk); #1;
        idex_flush = 0;
        check({31'b0,ex_reg_write_o}, 32'd0, "ID/EX flush: reg_write=0");
        check({31'b0,ex_mem_read_o},  32'd0, "ID/EX flush: mem_read=0");
        check(ex_rd_addr_o,           32'd0, "ID/EX flush: rd_addr=0");

        // ── TEST EX/MEM: Normal latch ──────────────────────────
        $display("\n--- EX/MEM Register: Normal Latch ---");
        ex_reg_write_i  = 1; ex_mem_read_i = 0;
        ex_alu_result_i = 32'd150;
        ex_zero_i       = 1;
        ex_rs2_data_i   = 32'd77;
        ex_rd_addr_i    = 5'd7;
        ex_branch_target_i = 32'd20;

        @(posedge clk); #1;
        check(mem_alu_result_o,    32'd150, "EX/MEM: alu_result latched");
        check(mem_rs2_data_o,      32'd77,  "EX/MEM: rs2_data latched");
        check(mem_rd_addr_o,       32'd7,   "EX/MEM: rd_addr latched");
        check(mem_branch_target_o, 32'd20,  "EX/MEM: branch_target latched");
        check({31'b0,mem_zero_o},  32'd1,   "EX/MEM: zero flag latched");

        // ── TEST MEM/WB: Normal latch ──────────────────────────
        $display("\n--- MEM/WB Register: Normal Latch ---");
        mem_reg_write_i  = 1;
        mem_mem_to_reg_i = 1;           // lw: pick memory data
        mem_read_data_i  = 32'hCAFE;    // data from memory
        mem_alu_result_i = 32'hDEAD;    // ALU result (address)
        mem_rd_addr_i    = 5'd9;

        @(posedge clk); #1;
        check(wb_read_data_o,          32'hCAFE, "MEM/WB: read_data latched");
        check(wb_alu_result_o,         32'hDEAD, "MEM/WB: alu_result latched");
        check(wb_rd_addr_o,            32'd9,    "MEM/WB: rd_addr latched");
        check({31'b0,wb_reg_write_o},  32'd1,    "MEM/WB: reg_write=1");
        check({31'b0,wb_mem_to_reg_o}, 32'd1,    "MEM/WB: mem_to_reg=1");

        // ── TEST: Reset clears everything ─────────────────────
        $display("\n--- Reset Clears All Registers ---");
        reset = 1;
        @(posedge clk); #1;
        reset = 0; #1;
        check(wb_read_data_o,  32'b0, "MEM/WB reset: read_data=0");
        check(wb_alu_result_o, 32'b0, "MEM/WB reset: alu_result=0");
        check(mem_alu_result_o,32'b0, "EX/MEM reset: alu_result=0");

        // ── Summary ───────────────────────────────────────────
        $display("\n========================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");

        $finish;
    end

endmodule
