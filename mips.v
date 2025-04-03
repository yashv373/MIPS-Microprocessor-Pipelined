`timescale 1ns/1ps

//===================================================
// MIPS Processor Design - 5-Stage Pipeline 
// Project Yashvardhan, Megh, Siddharth - EE-VLSI_MIT-Manipal
// Supports R-, I-, and J-type instructions.  
// NO hazard detection/forwarding is implemented.
//===================================================
module mips(input clk, input reset); // module instantiation
// below we declare all the registers we will need for our design.
  // -------------------------------
  // Pipeline Registers
  // -------------------------------
  reg [31:0] PC, IF_ID_instr, IF_ID_pc;
  reg [31:0] ID_EX_pc, ID_EX_rs, ID_EX_rt, ID_EX_imm;
  reg [4:0]  ID_EX_rd;  // For R-type: bits [15:11], for I-type: bits [20:16]
  reg [5:0]  ID_EX_funct;
  reg [3:0]  ID_EX_aluop;
  // Control signals: RegWrite, MemToReg, MemWrite, Jump, ZeroExtend, ALUSrc
  reg        ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite, ID_EX_jump,
             ID_EX_zero_extend, ID_EX_alusrc;
  
  reg [31:0] EX_MEM_alu, EX_MEM_writedata;
  reg [4:0]  EX_MEM_rd;
  reg        EX_MEM_regwrite, EX_MEM_memtoret, EX_MEM_memwrite;
  
  reg [31:0] MEM_WB_readdata, MEM_WB_alu;
  reg [4:0]  MEM_WB_rd;
  reg        MEM_WB_regwrite, MEM_WB_memtoret;
  
  // -------------------------------
  // Memories and Register File
  // -------------------------------
  reg [31:0] imem [0:1023];
  reg [31:0] dmem [0:1023];
  reg [31:0] regfile [0:31];
  
  // -------------------------------
  // Data Path Wires
  // -------------------------------
  wire [31:0] pc_plus4, pc_next, jump_address;
  wire [31:0] sign_extended, zero_extended, imm_value;
  wire [31:0] alu_src_b, alu_result;
  wire [3:0]  alu_control;
  
  // -------------------------------
  // PC Increment and Jump Target Calculation
  // -------------------------------
  adder pc_adder(.a(PC), .b(32'd4), .sum(pc_plus4));
  // Jump target computed using IF_ID_pc so that the upper 4 bits are correct.
  assign jump_address = {IF_ID_pc[31:28], IF_ID_instr[25:0], 2'b00};
  
  // -------------------------------
  // ALU and ALU Control
  // -------------------------------
  // For R-type (opcode == 0) we use a unique ALUop = 4'b1010 so that the alu_control
  // module decodes the funct field; I-type instructions use their direct ALUop.
  alu main_alu(.a(ID_EX_rs), .b(alu_src_b), .alu_control(alu_control), .result(alu_result));
  alu_control alu_ctrl(.funct(ID_EX_funct), .aluop(ID_EX_aluop), .alu_control(alu_control));
  
  // -------------------------------
  // Immediate Extension
  // -------------------------------
  sign_extend #(16,32) se(.in(IF_ID_instr[15:0]), .out(sign_extended));
  assign zero_extended = {16'b0, IF_ID_instr[15:0]};
  assign imm_value = ID_EX_zero_extend ? zero_extended : sign_extended;
  
  // -------------------------------
  // Multiplexers: For ALU{Source, Jump}
  // -------------------------------
  mux2 #(32) mux_alu_src(.d0(ID_EX_rt), .d1(ID_EX_imm), .sel(ID_EX_alusrc), .y(alu_src_b));
  mux2 #(32) mux_jump(.d0(pc_plus4), .d1(jump_address), .sel(ID_EX_jump), .y(pc_next));
  
  // ================================
  // Pipeline Stages
  // ================================
  
  // IF Stage: Fetch instruction and update PC.
  always @(posedge clk) begin
    if (reset) begin
      PC <= 0;
      IF_ID_instr <= 0;
      IF_ID_pc <= 0;
    end else begin
      IF_ID_instr <= imem[PC >> 2];
      IF_ID_pc <= PC;
      PC <= pc_next;
    end
  end
  
  // ID Stage: Decode instruction, read registers, extend immediate, and set control signals.
  always @(posedge clk) begin
    if (reset) begin
      ID_EX_pc <= 0;
      ID_EX_rs <= 0;
      ID_EX_rt <= 0;
      ID_EX_imm <= 0;
      ID_EX_rd <= 0;
      ID_EX_funct <= 0;
      ID_EX_aluop <= 0;
      {ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite, ID_EX_jump, ID_EX_zero_extend, ID_EX_alusrc} <= 0;
    end else begin
      ID_EX_pc <= IF_ID_pc;
      ID_EX_rs <= regfile[IF_ID_instr[25:21]];
      ID_EX_rt <= regfile[IF_ID_instr[20:16]];
      ID_EX_imm <= imm_value;
      ID_EX_funct <= IF_ID_instr[5:0];
      // Destination register: if opcode==0 (R-type) use bits [15:11]; else (I-type) use bits [20:16]
      ID_EX_rd <= (IF_ID_instr[31:26] == 6'b000000) ? IF_ID_instr[15:11] : IF_ID_instr[20:16];
      
      case (IF_ID_instr[31:26])
        6'b000000: begin // R-type
          // Set ALUop to 4'b1010 so that alu_control decodes using the funct field.
          {ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite,
           ID_EX_aluop, ID_EX_jump, ID_EX_zero_extend, ID_EX_alusrc}
            <= {1'b1, 1'b0, 1'b0, 4'b1010, 1'b0, 1'b0, 1'b0};
        end
        6'b001000: begin // ADDI
          {ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite,
           ID_EX_aluop, ID_EX_jump, ID_EX_zero_extend, ID_EX_alusrc}
            <= {1'b1, 1'b0, 1'b0, 4'b0000, 1'b0, 1'b0, 1'b1};
        end
        6'b001100: begin // ANDI
          {ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite,
           ID_EX_aluop, ID_EX_jump, ID_EX_zero_extend, ID_EX_alusrc}
            <= {1'b1, 1'b0, 1'b0, 4'b0010, 1'b0, 1'b1, 1'b1};
        end
        6'b001101: begin // ORI
          {ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite,
           ID_EX_aluop, ID_EX_jump, ID_EX_zero_extend, ID_EX_alusrc}
            <= {1'b1, 1'b0, 1'b0, 4'b0011, 1'b0, 1'b1, 1'b1};
        end
        6'b001010: begin // SLTI
          {ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite,
           ID_EX_aluop, ID_EX_jump, ID_EX_zero_extend, ID_EX_alusrc}
            <= {1'b1, 1'b0, 1'b0, 4'b0100, 1'b0, 1'b0, 1'b1};
        end
        6'b100011: begin // LW
          {ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite,
           ID_EX_aluop, ID_EX_jump, ID_EX_zero_extend, ID_EX_alusrc}
            <= {1'b1, 1'b1, 1'b0, 4'b0000, 1'b0, 1'b0, 1'b1};
        end
        6'b101011: begin // SW
          {ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite,
           ID_EX_aluop, ID_EX_jump, ID_EX_zero_extend, ID_EX_alusrc}
            <= {1'b0, 1'b0, 1'b1, 4'b0000, 1'b0, 1'b0, 1'b1};
        end
        6'b000010: begin // J
          {ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite,
           ID_EX_aluop, ID_EX_jump, ID_EX_zero_extend, ID_EX_alusrc}
            <= {1'b0, 1'b0, 1'b0, 4'b0000, 1'b1, 1'b0, 1'b0};
        end
        default: begin
          {ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite,
           ID_EX_aluop, ID_EX_jump, ID_EX_zero_extend, ID_EX_alusrc} <= 0;
        end
      endcase
    end
  end
  
  // EX Stage: Execute ALU operation and propagate control signals.
  always @(posedge clk) begin
    if (reset) begin
      EX_MEM_alu <= 0;
      EX_MEM_writedata <= 0;
      EX_MEM_rd <= 0;
      {EX_MEM_regwrite, EX_MEM_memtoret, EX_MEM_memwrite} <= 0;
    end else begin
      EX_MEM_alu <= alu_result;
      EX_MEM_writedata <= ID_EX_rt;
      EX_MEM_rd <= ID_EX_rd;
      {EX_MEM_regwrite, EX_MEM_memtoret, EX_MEM_memwrite}
         <= {ID_EX_regwrite, ID_EX_memtoret, ID_EX_memwrite};
    end
  end
  
  // MEM Stage: Memory access
  always @(posedge clk) begin
    if (reset) begin
      MEM_WB_readdata <= 0;
      MEM_WB_alu <= 0;
      MEM_WB_rd <= 0;
      {MEM_WB_regwrite, MEM_WB_memtoret} <= 0;
    end else begin
      if (EX_MEM_memwrite)
        dmem[EX_MEM_alu >> 2] <= EX_MEM_writedata;
      MEM_WB_readdata <= dmem[EX_MEM_alu >> 2];
      MEM_WB_alu <= EX_MEM_alu;
      MEM_WB_rd <= EX_MEM_rd;
      {MEM_WB_regwrite, MEM_WB_memtoret} <= {EX_MEM_regwrite, EX_MEM_memtoret};
    end
  end
  
  // WB Stage: Write back to register file.
  always @(posedge clk) begin
    if (reset) begin
      for (integer i = 0; i < 32; i = i + 1)
        regfile[i] <= 0;
    end else if (MEM_WB_regwrite && MEM_WB_rd != 0) begin
      regfile[MEM_WB_rd] <= MEM_WB_memtoret ? MEM_WB_readdata : MEM_WB_alu;
    end
  end
  
endmodule

//---------------------------
// Submodules
//---------------------------
module adder(input [31:0] a, b, output [31:0] sum);
  assign sum = a + b;
endmodule

module alu(input [31:0] a, b, input [3:0] alu_control, output reg [31:0] result);
  always @(*) begin
    case (alu_control)
      4'b0000: result = a + b;
      4'b0001: result = a - b;
      4'b0010: result = a & b;
      4'b0011: result = a | b;
      4'b0100: result = (a < b) ? 1 : 0;
      default: result = 0;
    endcase
  end
endmodule

module alu_control(input [5:0] funct, input [3:0] aluop, output reg [3:0] alu_control);
  always @(*) begin
    case (aluop)
      4'b1010: begin // R-type: decode using funct field
        case (funct)
          6'b100000: alu_control = 4'b0000; // ADD
          6'b100010: alu_control = 4'b0001; // SUB
          6'b100100: alu_control = 4'b0010; // AND
          6'b100101: alu_control = 4'b0011; // OR
          6'b101010: alu_control = 4'b0100; // SLT
          default:   alu_control = 4'b0000;
        endcase
      end
      default: begin // I-type: pass ALUop directly
        alu_control = aluop;
      end
    endcase
  end
endmodule

module sign_extend #(parameter IN = 16, parameter OUT = 32)
  (input [IN-1:0] in, output [OUT-1:0] out);
  assign out = {{OUT-IN{in[IN-1]}}, in};
endmodule

module mux2 #(parameter WIDTH = 32)
  (input [WIDTH-1:0] d0, d1, input sel, output [WIDTH-1:0] y);
  assign y = sel ? d1 : d0;
endmodule
