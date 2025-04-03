`timescale 1ns/1ps
// TESTBENCH 
module tb;
  reg clk, reset;
  mips cpu(clk, reset);
  
  // Clock generation: period = 10 ns
  always #5 clk = ~clk;
  
  // Testbench: Instruction and Data Memory Initialization
  initial begin
    clk = 0;
    reset = 1;
    
    //-------------------------------------------------------------------------
    // Instruction Memory Initialization – NOPs inserted to ensure proper WB.
    //-------------------------------------------------------------------------
    // Address 0: addi $s0, $zero, 5   --> $s0 = 5 (dest: reg16)
    cpu.imem[0] = 32'h20100005;
    cpu.imem[1] = 32'h00000000; // NOP
    cpu.imem[2] = 32'h00000000; // NOP
    
    // Address 3: addi $s1, $zero, 10  --> $s1 = 10 (dest: reg17)
    cpu.imem[3] = 32'h2011000A;
    cpu.imem[4] = 32'h00000000; // NOP
    cpu.imem[5] = 32'h00000000; // NOP
    
    // Extra NOP to ensure $s1 gets written before its use.
    cpu.imem[6] = 32'h00000000; // NOP
    
    // Address 7: add $t0, $s1, $s0     --> add $t0, $s1, $s0; Expected: 15, dest: reg8
    cpu.imem[7] = 32'h02304020; // Correct encoding for "add $t0, $s1, $s0"
    cpu.imem[8] = 32'h00000000; // NOP
    cpu.imem[9] = 32'h00000000; // NOP
    
    // Address 10: andi $s2, $s0, 0xF   --> Expected: $s2 = $s0 & 0xF = 5 & 15 = 5, dest: reg18
    cpu.imem[10] = 32'h3212000F;
    cpu.imem[11] = 32'h00000000; // NOP
    cpu.imem[12] = 32'h00000000; // NOP
    
    // Address 13: ori $s3, $s1, 0xF0    --> Expected: $s3 = $s1 | 0xF0 = 10 | 240 = 250 (fa), dest: reg19
    cpu.imem[13] = 32'h363300F0;
    cpu.imem[14] = 32'h00000000; // NOP
    cpu.imem[15] = 32'h00000000; // NOP
    
    // Address 16: slti $s4, $s1, 10     --> Expected: $s4 = ($s1 < 10)?1:0 = 0, dest: reg20
    cpu.imem[16] = 32'h2A34000A;
    cpu.imem[17] = 32'h00000000; // NOP
    cpu.imem[18] = 32'h00000000; // NOP
    
    // Address 19: sw $t0, 16($zero)    --> Expected: store $t0 (15) to dmem address 16 (index 4)
    cpu.imem[19] = 32'hAC080010;
    cpu.imem[20] = 32'h00000000; // NOP
    cpu.imem[21] = 32'h00000000; // NOP
    
    // Address 22: lw $t1, 16($zero)    --> Expected: load 15 into $t1 (dest: reg9)
    cpu.imem[22] = 32'h8C090010;
    cpu.imem[23] = 32'h00000000; // NOP
    cpu.imem[24] = 32'h00000000; // NOP
    
    // Address 25: addi $s6, $zero, 0xFF  --> Expected: $s6 = 0xFF, dest: reg22
    cpu.imem[25] = 32'h201600FF;
    cpu.imem[26] = 32'h00000000; // NOP
    cpu.imem[27] = 32'h00000000; // NOP
    
    // Fill the rest of imem with NOPs.
    for (integer i = 28; i < 1024; i = i + 1)
      cpu.imem[i] = 32'h00000000;
    
    //-------------------------------------------------------------------------
    // Initialize register file and data memory to zero.
    //-------------------------------------------------------------------------
    for (integer i = 0; i < 32; i = i + 1)
      cpu.regfile[i] = 0;
    for (integer i = 0; i < 1024; i = i + 1)
      cpu.dmem[i] = 0;
      
    // Release reset after an extended interval, then wait for pipeline flush.
    #50 reset = 0;
    #800;
    
    // Display final states.
    $display("\nFinal Register/Memory State at ~350 ns:");
    $display("$s0 = %d (expected 5)",  cpu.regfile[16]);
    $display("$s1 = %d (expected 10)", cpu.regfile[17]);
    $display("$t0 = %d (expected 15)", cpu.regfile[8]);
    $display("$s2 = %h (expected 5)",  cpu.regfile[18]);
    $display("$s3 = %h (expected fa)", cpu.regfile[19]);
    $display("$s4 = %d (expected 0)",  cpu.regfile[20]);
    $display("$t1 = %d (expected 15)", cpu.regfile[9]);
    $display("Mem[4] = %d (expected 15)", cpu.dmem[4]);
    $display("$s6 = %h (expected ff)", cpu.regfile[22]);
    
    $finish;
  end
  
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb);
    $monitor("Time=%0t: PC=%h, Instr=%h", $time, cpu.PC, cpu.IF_ID_instr);
  end
  
endmodule
