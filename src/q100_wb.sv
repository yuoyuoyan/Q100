// WB module, currently support RV32I only
// Fifth stage of the pipeline, WB
`include "q100_config.svh"
module q100_wb(
    input  clk,
	
	// mem result
	input                              WB_i,
	input                              CSR_i,
	input        [`LEN_REG_VAL-1:0]    csr_value_i,
	input        [`LEN_CSR_ADDR-1:0]   csr_addr_i,
	input        [`LEN_OPCODE-1:0]     opcode_i,
	input        [`LEN_REG_VAL-1:0]    dtcm_rd_data_i,
	input        [`LEN_REG_VAL-1:0]    alu_result_i,
	input                              wb_sel_i, // 1 is dtcm_data, 0 is alu_result
	input        [`LEN_RD-1:0]         rd_i,
	
	// data write into registers
	output logic [`LEN_REG_VAL-1:0]    csr_value_o,
	output logic [`LEN_CSR_ADDR-1:0]   csr_addr_o,
	output logic                       csr_vld_o,
    output logic [`LEN_REG_VAL-1:0]    xn_result_o,
	output logic [`LEN_REG-1:0]        xn_wr_en_o,
	output logic                       reg_wr,
	output logic [`LEN_RD-1:0]         rd_o
);

// send the result into related register
assign xn_result_o = wb_sel_i ? dtcm_rd_data_i : alu_result_i;

assign xn_wr_en_o[0] = 1'b0; // No write to zero register
generate
    for(genvar i=1; i<`LEN_REG; i++) begin : write_enable_search
	    assign xn_wr_en_o[i] = (rd_i==i) ? WB_i : 1'b0;
	end
endgenerate

// Feedback signal to ALU
assign reg_wr = WB_i;
assign rd_o = rd_i;

// CSR value
assign csr_vld_o = CSR_i;
assign csr_value_o = csr_value_i;
assign csr_addr_o = csr_addr_i;

endmodule
