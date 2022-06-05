// ALU module, currently support RV32I only
// Third stage of the pipeline, EX
`include "q100_config.svh"
module q100_alu(
    input  clk,
	
	// decode result
	input                              WB_i,
	input                              M_i,
	input                              EX_i,
	input                              CSR_i,
	input        [`LEN_REG_VAL-1:0]    pc_i,
	input        [`LEN_REG_VAL-1:0]    xn_rs1_i,
	input        [`LEN_REG_VAL-1:0]    xn_rs2_i,
	input        [`LEN_RS1-1:0]        rs1_i,
	input        [`LEN_RS2-1:0]        rs2_i,
	input        [`LEN_RD-1:0]         rd_i,
	input        [`LEN_FUNCT3-1:0]     funct3_i,
	input        [`LEN_FUNCT7-1:0]     funct7_i,
	input        [`LEN_OPCODE-1:0]     opcode_i,
	input        [`LEN_IMM-1:0]        imm_i,
	
	// pc flushing signal to IF
	output logic [`LEN_REG_VAL-1:0]    pc_flush_o,
	output logic                       pc_flush_vld_o,
	
	// bypass data from WB
    input        [`LEN_REG_VAL-1:0]    WB_result_i,
	input                              WB_reg_wr_i,
	input        [`LEN_RD-1:0]         WB_rd_i,
	
	// alu result to MEM
	output logic                       WB_o,
	output logic                       CSR_o,
	output logic                       M_o,
	output logic                       reg_wr_o,
	output logic [`LEN_REG_VAL-1:0]    alu_result_o,
	output logic [`LEN_REG_VAL-1:0]    csr_value_o,
	output logic [`LEN_CSR_ADDR-1:0]   csr_addr_o,
	output logic [`LEN_RD-1:0]         rd_o,
	output logic [`LEN_REG_VAL-1:0]    xn_rs2_o,
	output logic [`LEN_FUNCT3-1:0]     funct3_o,
	output logic [`LEN_FUNCT7-1:0]     funct7_o,
	output logic [`LEN_OPCODE-1:0]     opcode_o
);

// signal selection to the port A and B of ALU
// controlled by the bypass detection
typedef enum {PORT_RS, PORT_ALU, PORT_WB, PORT_IMM} t_alu_sel;
t_alu_sel porta_sel;
t_alu_sel portb_sel;
// operation selection
typedef enum {ALU_ADD, ALU_SUB, ALU_LT, ALU_LTU, ALU_SLL, ALU_SRL, ALU_SRA, ALU_AND, ALU_OR, ALU_XOR, ALU_IMM, ALU_MUL} t_alu_op;
t_alu_op alu_op_sel, alu_op_sel_d;
logic [`LEN_REG_VAL-1:0]    alu_result_r;

// bypass detection unit
// totally 4 conflic cases
// 1. C1(A) : EX/MEM.Regwr and (EX/MEM.Regrd!=0) and (EX/MEM.Regrd==ID/EX.Rs1)
// 2. C1(B) : EX/MEM.Regwr and (EX/MEM.Regrd!=0) and (EX/MEM.Regrd==ID/EX.Rs2)
// 3. C2(A) : MEM/WB.Regwr and (MEM/WB.Regrd!=0) and (EX/MEM.Regrd!=ID/EX.Rs1) and (MEM/WR.Regrd==ID/EX.Rs1)
// 4. C2(B) : MEM/WB.Regwr and (MEM/WB.Regrd!=0) and (EX/MEM.Regrd!=ID/EX.Rs2) and (MEM/WR.Regrd==ID/EX.Rs2)
always_comb begin
    if(reg_wr_o & (rd_o!=0) & (rd_o==rs1_i)) 
	    porta_sel = PORT_ALU;
	else if(WB_reg_wr_i & (WB_rd_i!=0) & (rd_o!=rs1_i) & (WB_rd_i==rs1_i))
	    porta_sel = PORT_WB;
	else
	    porta_sel = PORT_RS;

	if(opcode_i==`OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI ||
	   opcode_i==`OPCODE_LUI ||
	   opcode_i==`OPCODE_AUIPC ||
	   opcode_i==`OPCODE_LB_LH_LW_LBU_LHU ||
	   opcode_i==`OPCODE_SB_SH_SW)
	    portb_sel = PORT_IMM;
	else if(reg_wr_o & (rd_o!=0) & (rd_o==rs2_i)) 
	    portb_sel = PORT_ALU; 
	else if(WB_reg_wr_i & (WB_rd_i!=0) & (rd_o!=rs2_i) & (WB_rd_i==rs2_i))
	    portb_sel = PORT_WB;
	else
	    portb_sel = PORT_RS;
end

// ALU operation selection based on opcode and funct3
always_comb begin
    casez({EX_i, opcode_i, funct3_i})
	{1'b1, `OPCODE_LUI, {`LEN_FUNCT3{1'b?}}} : 
	    alu_op_sel = ALU_IMM;
	{1'b1, `OPCODE_LB_LH_LW_LBU_LHU, {`LEN_FUNCT3{1'b?}}} : 
	    alu_op_sel = ALU_ADD;
	{1'b1, `OPCODE_SB_SH_SW, {`LEN_FUNCT3{1'b?}}} :
	    alu_op_sel = ALU_ADD;
	{1'b1, `OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI, `FUNCT3_ADDI} :
	    alu_op_sel = ALU_ADD;
	{1'b1, `OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI, `FUNCT3_SLTI} :
	    alu_op_sel = ALU_LT;
	{1'b1, `OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI, `FUNCT3_SLTIU} :
	    alu_op_sel = ALU_LTU;
	{1'b1, `OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI, `FUNCT3_XORI} :
	    alu_op_sel = ALU_XOR;
	{1'b1, `OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI, `FUNCT3_ORI} :
	    alu_op_sel = ALU_OR;
	{1'b1, `OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI, `FUNCT3_ANDI} :
	    alu_op_sel = ALU_AND;
	{1'b1, `OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI, `FUNCT3_SLLI} :
	    alu_op_sel = ALU_SLL;
	{1'b1, `OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI, `FUNCT3_SRLI_SRAI} :
	    alu_op_sel = funct7_i[5] ? ALU_SRA : ALU_SRL;
	{1'b1, `OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND, `FUNCT3_ADD_SUB} :
	    alu_op_sel = funct7_i[0] ? ALU_MUL : (funct7_i[5] ? ALU_SUB : ALU_ADD);
	{1'b1, `OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND, `FUNCT3_SLL} :
	    alu_op_sel = ALU_SLL;
	{1'b1, `OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND, `FUNCT3_SLT} :
	    alu_op_sel = ALU_LT;
	{1'b1, `OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND, `FUNCT3_SLTU} :
	    alu_op_sel = ALU_LTU;
	{1'b1, `OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND, `FUNCT3_XOR} :
	    alu_op_sel = ALU_XOR;
	{1'b1, `OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND, `FUNCT3_SRL_SRA} :
	    alu_op_sel = funct7_i[5] ? ALU_SRA : ALU_SRL;
	{1'b1, `OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND, `FUNCT3_OR} :
	    alu_op_sel = ALU_OR;
	{1'b1, `OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND, `FUNCT3_AND} :
	    alu_op_sel = ALU_AND;
	default:
	    alu_op_sel = ALU_ADD;
	endcase
end
always_ff @(posedge clk) alu_op_sel_d <= alu_op_sel;

// two ports to ALU
logic [`LEN_REG_VAL-1:0] alu_porta, alu_portb;
always_comb begin
    case(porta_sel)
	PORT_RS : alu_porta = xn_rs1_i;
	PORT_ALU: alu_porta = alu_result_o;
	PORT_WB : alu_porta = WB_result_i;
	endcase
	case(portb_sel)
	PORT_RS : alu_portb = xn_rs2_i;
	PORT_ALU: alu_portb = alu_result_o;
	PORT_WB : alu_portb = WB_result_i;
	PORT_IMM: alu_portb = imm_i;
	endcase
end

// pc change
logic branch_en;
always_comb begin
    casez({opcode_i, funct3_i})
	{`OPCODE_JAL, {`LEN_FUNCT3{1'b?}}} : branch_en = 1'b1;
	{`OPCODE_JALR, {`LEN_FUNCT3{1'b?}}} : branch_en = 1'b1;
	{`OPCODE_BEQ_BNE_BLT_BGE_BLTU_BGEU, `FUNCT3_BEQ} : 
	    branch_en = (alu_porta==alu_portb) ? 1'b1 : 1'b0;
	{`OPCODE_BEQ_BNE_BLT_BGE_BLTU_BGEU, `FUNCT3_BNE} :
	    branch_en = (alu_porta!=alu_portb) ? 1'b1 : 1'b0;
	{`OPCODE_BEQ_BNE_BLT_BGE_BLTU_BGEU, `FUNCT3_BLT} :
	    branch_en = ($signed(alu_porta)<$signed(alu_portb)) ? 1'b1 : 1'b0;
	{`OPCODE_BEQ_BNE_BLT_BGE_BLTU_BGEU, `FUNCT3_BGE} :
	    branch_en = ($signed(alu_porta)>=$signed(alu_portb)) ? 1'b1 : 1'b0;
	{`OPCODE_BEQ_BNE_BLT_BGE_BLTU_BGEU, `FUNCT3_BLTU} :
	    branch_en = (alu_porta<alu_portb) ? 1'b1 : 1'b0;
	{`OPCODE_BEQ_BNE_BLT_BGE_BLTU_BGEU, `FUNCT3_BGEU} :
	    branch_en = (alu_porta>=alu_portb) ? 1'b1 : 1'b0;
	default: branch_en = 1'b0;
	endcase
end
always_ff @(posedge clk) begin
    pc_flush_o <= (opcode_i==`OPCODE_JALR) ? alu_porta + imm_i : pc_i + imm_i;
    pc_flush_vld_o <= branch_en;
end

// delay the branch_en to disable some invalid instruction
logic [2:0] branch_en_d;
always_ff @(posedge clk) branch_en_d <= {branch_en_d[1:0], branch_en};

// dsp part for multiplication
logic signed [`LEN_REG_VAL-1:0] alu_dsp;
always_ff @(posedge clk)
    alu_dsp <= $signed(alu_porta[`LEN_PORTA_MUL-1:0]) * $signed(alu_portb[`LEN_PORTB_MUL-1:0]);

// ALU part
logic [`LEN_REG_VAL-1:0] alu_result;
always_comb begin
    case(alu_op_sel)
	ALU_ADD: alu_result = alu_porta + alu_portb;
	ALU_SUB: alu_result = alu_porta - alu_portb;
	ALU_LT : alu_result = ($signed(alu_porta) < $signed(alu_portb)) ? 'h1 : 'h0;
	ALU_LTU: alu_result = (alu_porta < alu_portb) ? 'h1 : 'h0;
	ALU_SLL: alu_result = alu_porta << (alu_portb[4:0]);
	ALU_SRL: alu_result = alu_porta >> (alu_portb[4:0]);
	ALU_SRA: alu_result = $signed(alu_porta) >>> (alu_portb[4:0]);
	ALU_AND: alu_result = alu_porta & alu_portb;
	ALU_OR : alu_result = alu_porta | alu_portb;
	ALU_XOR: alu_result = alu_porta ^ alu_portb;
	ALU_IMM: alu_result = alu_portb;
	default: alu_result = alu_portb;
	endcase
end

// signal pass to the next stage
always_ff @(posedge clk) begin
    WB_o <= WB_i & (branch_en_d==0);
	M_o <= M_i & (branch_en_d==0);
	reg_wr_o <= ( (opcode_i==`OPCODE_LB_LH_LW_LBU_LHU) |
                  (opcode_i==`OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI) |
				  (opcode_i==`OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND) |
				  (opcode_i==`OPCODE_AUIPC) |
				  (opcode_i==`OPCODE_LUI)) ?
				  1'b1 : 1'b0;
	alu_result_r <= alu_result;
	rd_o <= rd_i;
	funct3_o <= funct3_i;
	funct7_o <= funct7_i;
	// need to detect bypass for the rs2 data
	if(reg_wr_o & (rd_o!=0) & (rd_o==rs2_i)) 
	    xn_rs2_o <= alu_result_o;
	else if(WB_reg_wr_i & (WB_rd_i!=0) & (rd_o!=rs2_i) & (WB_rd_i==rs2_i))
	    xn_rs2_o <= WB_result_i;
	else xn_rs2_o <= xn_rs2_i;
	opcode_o <= opcode_i;
end
assign alu_result_o = (alu_op_sel_d==ALU_MUL) ? alu_dsp : alu_result_r;

// CSR command
always_ff @(posedge clk) begin
    CSR_o <= CSR_i & (branch_en_d==0);
	csr_value_o <= (funct3_i==`FUNCT3_CSRRW ||
	                funct3_i==`FUNCT3_CSRRS ||
					funct3_i==`FUNCT3_CSRRC) ?
					xn_rs1_i : {{(`LEN_REG_VAL-`LEN_RS1){1'b0}}, rs1_i};
	csr_addr_o <= imm_i[`LEN_CSR_ADDR-1:0];
end

endmodule
