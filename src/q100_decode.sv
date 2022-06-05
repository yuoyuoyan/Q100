// Decoder module, currently support RV32I only
// second step of the pipeline, ID
// get the related info from instruction, and fetch the registers for alu
`include "q100_config.svh"
module q100_decode(
    input     clk,
	
	// instruction from fetch module
	input  logic [`LEN_REG_VAL-1:0]     pc_i,
	input  logic                        keep_i,
	input  logic [`LEN_RS1-1:0]         rs1_i,
	input  logic [`LEN_RS2-1:0]         rs2_i,
	input  logic [`LEN_RD-1:0]          rd_i,
	input  logic [`LEN_FUNCT3-1:0]      funct3_i,
	input  logic [`LEN_FUNCT7-1:0]      funct7_i,
	input  logic [`LEN_IMM-1:0]         imm_i,
	input  logic [`LEN_OPCODE-1:0]      opcode_i,
	
	// register access
	input        [`LEN_REG-1:0][`LEN_REG_VAL-1:0] xn_i,
	input        [`LEN_RD-1:0]         rd_WB_i,
	input        [`LEN_REG_VAL-1:0]    xn_result_WB_i,
	input                              reg_wr_WB_i,
	
	// decode result to EX
	output logic                       WB_o,
	output logic                       M_o,
	output logic                       EX_o,
	output logic                       CSR_o,
	output logic [`LEN_REG_VAL-1:0]    pc_o,
	output logic [`LEN_REG_VAL-1:0]    xn_rs1_o,
	output logic [`LEN_REG_VAL-1:0]    xn_rs2_o,
	output logic [`LEN_RS1-1:0]        rs1_o,
	output logic [`LEN_RS2-1:0]        rs2_o,
	output logic [`LEN_RD-1:0]         rd_o,
	output logic [`LEN_FUNCT3-1:0]     funct3_o,
	output logic [`LEN_FUNCT7-1:0]     funct7_o,
	output logic [`LEN_OPCODE-1:0]     opcode_o,
	output logic [`LEN_IMM-1:0]        imm_o
);

// get two source registers
always_ff @(posedge clk) begin
	xn_rs1_o <= (opcode_i==`OPCODE_AUIPC) ? pc_i : 
	            (reg_wr_WB_i & (rs1_i==rd_WB_i)) ? xn_result_WB_i : xn_i[rs1_i];
	xn_rs2_o <= (reg_wr_WB_i & (rs2_i==rd_WB_i)) ? xn_result_WB_i : xn_i[rs2_i];
end

// config if the later pipe should work
always_ff @(posedge clk) begin
    if(keep_i) begin
	    WB_o <= 1'b0;
		M_o <= 1'b0;
		EX_o <= 1'b0;
	end
    else begin
	    if(opcode_i==`OPCODE_LUI ||
		   opcode_i==`OPCODE_AUIPC ||
		   opcode_i==`OPCODE_JAL ||
		   opcode_i==`OPCODE_JALR ||
		   opcode_i==`OPCODE_LB_LH_LW_LBU_LHU ||
		   opcode_i==`OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI ||
		   opcode_i==`OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND)
		    WB_o <= 1'b1;
		else WB_o <= 1'b0;
		
		if(opcode_i==`OPCODE_LB_LH_LW_LBU_LHU ||
		   opcode_i==`OPCODE_SB_SH_SW)
		    M_o <= 1'b1;
		else M_o <= 1'b0;
		
		if(opcode_i==`OPCODE_LB_LH_LW_LBU_LHU ||
		   opcode_i==`OPCODE_SB_SH_SW ||
		   opcode_i==`OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI ||
		   opcode_i==`OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND ||
		   opcode_i==`OPCODE_LUI ||
		   opcode_i==`OPCODE_AUIPC)
		    EX_o <= 1'b1;
		else EX_o <= 1'b0;
		
		if(opcode_i==`OPCODE_ECALL_EBREAK_CSR)
		    CSR_o <= 1'b1;
		else
		    CSR_o <= 1'b0;
	end
end

// pipe delay the info from IF to EX
always_ff @(posedge clk) begin
    if(keep_i) begin
	    pc_o <= 0;
        rs1_o <= 0;
	    rs2_o <= 0;
	    rd_o <= 0;
	    funct3_o <= 0;
	    funct7_o <= 0;
	    imm_o <= 0;
	    opcode_o <= 0;
	end
	else begin
        pc_o <= pc_i;
        rs1_o <= rs1_i;
	    rs2_o <= rs2_i;
	    rd_o <= rd_i;
	    funct3_o <= funct3_i;
	    funct7_o <= funct7_i;
	    imm_o <= imm_i;
	    opcode_o <= opcode_i;
	end
end

endmodule
