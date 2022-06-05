// Fetch module, use PC to fetch instruction from ITCM
// first step of the pipeline, IF
`include "q100_config.svh"
module q100_fetch(
    input clk,
	input rst,
	
	// control input to flush pc
	input  logic [`LEN_REG_VAL-1:0]     pc_flush_i,
	input  logic                        pc_flush_vld_i,
	input  logic                        pause_i,
	
	// To itcm
	output logic [`ITCM_ADDR_WIDTH-1:0] itcm_addr_o,
	input        [`ITCM_DATA_WIDTH-1:0] itcm_data_i,
	
	// output registers and feedback signals from other pipe stages
	input        [`LEN_OPCODE-1:0]      opcode_from_ID_i,
	input        [`LEN_RD-1:0]          rd_from_ID_i,
	output logic [`LEN_REG_VAL-1:0]     pc_o,
	output logic                        keep_o,
	output logic [`LEN_RS1-1:0]         rs1_o,
	output logic [`LEN_RS2-1:0]         rs2_o,
	output logic [`LEN_RD-1:0]          rd_o,
	output logic [`LEN_FUNCT3-1:0]      funct3_o,
	output logic [`LEN_FUNCT7-1:0]      funct7_o,
	output logic [`LEN_IMM-1:0]         imm_o,
	output logic [`LEN_OPCODE-1:0]      opcode_o
);

// Load-use detection, to keep the pc and current IR
logic keep;
always_comb begin
    keep = (opcode_from_ID_i == `OPCODE_LB_LH_LW_LBU_LHU) & ((rd_from_ID_i == rs1_o | rd_from_ID_i == rs2_o)) ? 1'b1 : 1'b0;
end
assign keep_o = keep;

// Here to store the important PC
logic [`LEN_REG_VAL-1:0] pc;
logic [`LEN_REG_VAL-1:0] pc_add4;
assign pc_add4 = pc + 4;
always_ff @(posedge clk)
    if(rst) pc <= 0;
    else if(keep | pause_i) pc <= pc;
    else pc <= pc_flush_vld_i ? pc_flush_i+4 : pc_add4;
	
// Delay the pc for the branch use
logic [`LEN_REG_VAL-1:0] pc_d;
always_ff @(posedge clk) pc_d <= pc_flush_vld_i ? pc_flush_i : pc;

// ITCM read request based on PC
assign itcm_addr_o = pc_flush_vld_i ? pc_flush_i : pc;

// Send out the instr received from ITCM, depart it
logic [`LEN_INSTR-1:0] instr, instr_d;
always_ff @(posedge clk)
    if(rst) instr_d <= itcm_data_i;
    else if(pc_d!=pc) instr_d <= itcm_data_i;
assign instr = (pc_d==pc) ? instr_d : itcm_data_i;

always_ff @(posedge clk) begin
    if(rst) begin
	    pc_o <= 0;
	    rs1_o <= 0;
	    rs2_o <= 0;
	    rd_o <= 0;
	    funct3_o <= 0;
	    funct7_o <= 0;
	    opcode_o <= 0;
		imm_o <= 0; 
	end
	else if(!keep) begin
	    pc_o <= pc_d;
		if( instr[6:0]==`OPCODE_LUI ||
		    instr[6:0]==`OPCODE_AUIPC ||
		    instr[6:0]==`OPCODE_JAL
		    )
	        rs1_o <= 0;
		else
		    rs1_o <= instr[19:15];
		if( instr[6:0]==`OPCODE_LUI ||
		    instr[6:0]==`OPCODE_AUIPC ||
		    instr[6:0]==`OPCODE_JAL ||
		    instr[6:0]==`OPCODE_JALR ||
		    instr[6:0]==`OPCODE_LB_LH_LW_LBU_LHU ||
		    instr[6:0]==`OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI ||
			instr[6:0]==`OPCODE_ECALL_EBREAK_CSR
		    )
		    rs2_o <= 0;
		else
	        rs2_o <= instr[24:20];
	    rd_o <= instr[11:7];
	    funct3_o <= instr[14:12];
	    funct7_o <= instr[31:25];
	    opcode_o <= instr[6:0];
	    // I type
	    if( (instr[6:0]==`OPCODE_JALR) ||
            (instr[6:0]==`OPCODE_LB_LH_LW_LBU_LHU) ||
	    	(instr[6:0]==`OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI) ||
            (instr[6:0]==`OPCODE_FENCE) ||
            (instr[6:0]==`OPCODE_ECALL_EBREAK_CSR) )
	    	imm_o <= {{(`LEN_IMM-12){instr[31]}}, instr[31:20]};
	    // S type
	    else if( (instr[6:0]==`OPCODE_SB_SH_SW) )
	        imm_o <= {{(`LEN_IMM-12){instr[31]}}, instr[31:25], instr[11:7]};
	    // B type
	    else if( (instr[6:0]==`OPCODE_BEQ_BNE_BLT_BGE_BLTU_BGEU) )
	        imm_o <= {{(`LEN_IMM-13){instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
	    // U type
	    else if( (instr[6:0]==`OPCODE_LUI) ||
                 (instr[6:0]==`OPCODE_AUIPC) )
	    	imm_o <= {instr[31:12], 12'h0};
	    // J type
	    else if( (instr[6:0]==`OPCODE_JAL) )
	        imm_o <= {{(`LEN_IMM-21){instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
	    // R type or other cases
	    else imm_o <= 0;
	end
end

endmodule
