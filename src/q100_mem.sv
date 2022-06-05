// MEM module, currently support RV32I only
// Fourth stage of the pipeline, MEM
`include "q100_config.svh"
module q100_mem(
    input  clk,
	
	// alu result
	input                              WB_i,
	input                              CSR_i,
	input                              M_i,
	input                              reg_wr_i,
	input        [`LEN_REG_VAL-1:0]    alu_result_i,
	input        [`LEN_REG_VAL-1:0]    csr_value_i,
	input        [`LEN_CSR_ADDR-1:0]   csr_addr_i,
	input        [`LEN_RD-1:0]         rd_i,
	input        [`LEN_REG_VAL-1:0]    xn_rs2_i,
	input        [`LEN_FUNCT3-1:0]     funct3_i,
	input        [`LEN_FUNCT7-1:0]     funct7_i,
	input        [`LEN_OPCODE-1:0]     opcode_i,
	
	// interface to memory
    output logic [`DTCM_ADDR_WIDTH-1:0]dtcm_rw_addr_o,
	input        [`DTCM_DATA_WIDTH-1:0]dtcm_rd_data_i,
	output logic [`DTCM_DATA_WIDTH-1:0]dtcm_wr_data_o,
	output logic [`DTCM_BANK-1:0]      dtcm_rw_en_o, // 1 is write, 0 is read
	
	// mem result to WB
	output logic                       WB_o,
    output logic                       CSR_o,
	output logic [`LEN_REG_VAL-1:0]    csr_value_o,
	output logic [`LEN_CSR_ADDR-1:0]   csr_addr_o,
	output logic [`LEN_OPCODE-1:0]     opcode_o,
	output logic [`LEN_REG_VAL-1:0]    dtcm_rd_data_o,
	output logic [`LEN_REG_VAL-1:0]    alu_result_o,
	output logic                       wb_sel_o, // 1 is dtcm_data, 0 is alu_result
	output logic [`LEN_RD-1:0]         rd_o
);

// data write into DTCM
// and the read request if not writing
always_comb begin
    dtcm_rw_addr_o = alu_result_i[`DTCM_ADDR_WIDTH-1:0];
	dtcm_wr_data_o = xn_rs2_i;
	dtcm_rw_en_o[0] = (opcode_i==`OPCODE_SB_SH_SW) ? M_i : 1'b0;
	dtcm_rw_en_o[1] = ((opcode_i==`OPCODE_SB_SH_SW) & (funct3_i!=`FUNCT3_SB)) ? M_i : 1'b0;
	dtcm_rw_en_o[2] = ((opcode_i==`OPCODE_SB_SH_SW) & (funct3_i==`FUNCT3_SW)) ? M_i : 1'b0;
	dtcm_rw_en_o[3] = ((opcode_i==`OPCODE_SB_SH_SW) & (funct3_i==`FUNCT3_SW)) ? M_i : 1'b0;
end

// signal pass to the next stage
always_comb begin
    dtcm_rd_data_o = dtcm_rd_data_i;
end
always_ff @(posedge clk) begin
    WB_o <= WB_i;
	opcode_o <= opcode_i;
	alu_result_o <= alu_result_i;
	wb_sel_o <= (opcode_i==`OPCODE_LB_LH_LW_LBU_LHU) ? 1'b1 : 1'b0;
	rd_o <= rd_i;
	CSR_o <= CSR_i;
	csr_value_o <= csr_value_i;
	csr_addr_o <= csr_addr_i;
end

endmodule
