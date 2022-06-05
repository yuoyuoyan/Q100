// Execute module, include decoder, alu, csr, key registers
`include "q100_config.svh"
module q100_exu(
    input clk,
	input rst,
	
	// To itcm
	output logic [`ITCM_ADDR_WIDTH-1:0] itcm_addr_o,
	output logic                        itcm_we_o,
	input        [`ITCM_DATA_WIDTH-1:0] itcm_data_i,
	output logic [`ITCM_DATA_WIDTH-1:0] itcm_data_o,
	
	// To dtcm
	output logic [`DTCM_ADDR_WIDTH-1:0] dtcm_addr_o,
	output logic [`DTCM_BANK-1:0]       dtcm_we_o,
	input        [`DTCM_DATA_WIDTH-1:0] dtcm_data_i,
	output logic [`DTCM_DATA_WIDTH-1:0] dtcm_data_o,
	
	// Special signals
	output logic                        done_intr_o
);

// output signal from fetch module
logic [`LEN_REG_VAL-1:0]     pc_fetch_decode;
logic                        keep_fetch_decode;
logic [`LEN_RS1-1:0]         rs1_fetch_decode;
logic [`LEN_RS2-1:0]         rs2_fetch_decode;
logic [`LEN_RD-1:0]          rd_fetch_decode;
logic [`LEN_FUNCT3-1:0]      funct3_fetch_decode;
logic [`LEN_FUNCT7-1:0]      funct7_fetch_decode;
logic [`LEN_IMM-1:0]         imm_fetch_decode;
logic [`LEN_OPCODE-1:0]      opcode_fetch_decode;
// output signal from decode
logic [`LEN_RD-1:0]          rd_decode_fetch;
logic [`LEN_OPCODE-1:0]      opcode_decode_fetch;
logic                        WB_decode_alu;
logic                        CSR_decode_alu;
logic                        M_decode_alu;
logic                        EX_decode_alu;
logic [`LEN_REG_VAL-1:0]     pc_decode_alu;
logic [`LEN_REG_VAL-1:0]     xn_rs1_decode_alu;
logic [`LEN_REG_VAL-1:0]     xn_rs2_decode_alu;
logic [`LEN_RS1-1:0]         rs1_decode_alu;
logic [`LEN_RS2-1:0]         rs2_decode_alu;
logic [`LEN_RD-1:0]          rd_decode_alu;
logic [`LEN_FUNCT3-1:0]      funct3_decode_alu;
logic [`LEN_FUNCT7-1:0]      funct7_decode_alu;
logic [`LEN_OPCODE-1:0]      opcode_decode_alu;
logic [`LEN_IMM-1:0]         imm_decode_alu;
// output signal from alu
logic [`LEN_REG_VAL-1:0]     pc_flush_alu_fetch;
logic                        pc_flush_vld_alu_fetch;
logic                        WB_alu_mem;
logic                        CSR_alu_mem;
logic                        M_alu_mem;
logic                        reg_wr_alu_mem;
logic [`LEN_REG_VAL-1:0]     alu_result_alu_mem;
logic [`LEN_CSR-1:0]         csr_value_alu_mem;
logic [`LEN_CSR_ADDR-1:0]    csr_addr_alu_mem;
logic [`LEN_RD-1:0]          rd_alu_mem;
logic [`LEN_REG_VAL-1:0]     xn_rs2_alu_mem;
logic [`LEN_FUNCT3-1:0]      funct3_alu_mem;
logic [`LEN_FUNCT7-1:0]      funct7_alu_mem;
logic [`LEN_OPCODE-1:0]      opcode_alu_mem;
// output signal from memory access
logic                        WB_mem_wb;
logic                        CSR_mem_wb;
logic [`LEN_CSR-1:0]         csr_value_mem_wb;
logic [`LEN_CSR_ADDR-1:0]    csr_addr_mem_wb;
logic [`LEN_OPCODE-1:0]      opcode_mem_wb;
logic [`LEN_REG_VAL-1:0]     dtcm_rd_data_mem_wb;
logic [`LEN_REG_VAL-1:0]     alu_result_mem_wb;
logic                        wb_sel_mem_wb;
logic [`LEN_RD-1:0]          rd_mem_wb;
// output signal from write back
logic [`LEN_REG_VAL-1:0]     xn_result_wb_reg;
logic [`LEN_REG-1:0]         xn_wr_en_wb_reg;
logic [`LEN_REG_VAL-1:0]     xn_result_wb_alu;
logic [`LEN_REG_VAL-1:0]     xn_result_wb_decode;
logic                        reg_wr_wb_alu;
logic                        reg_wr_wb_decode;
logic [`LEN_RD-1:0]          rd_wb_alu;
logic [`LEN_RD-1:0]          rd_wb_decode;
logic                        csr_vld_wb_csr;
logic [`LEN_CSR-1:0]         csr_value_wb_csr;
logic [`LEN_CSR_ADDR-1:0]    csr_addr_wb_csr;
// output signal from registers
logic [`LEN_REG-1:0][`LEN_REG_VAL-1:0] xn_reg_decode;

q100_fetch u_fetch(
    .clk,
	.rst,
	// control input to flush pc
	.pc_flush_i     (pc_flush_alu_fetch),
	.pc_flush_vld_i (pc_flush_vld_alu_fetch),
	.pause_i        (done_intr_o),
	// To itcm
	.itcm_addr_o,
	.itcm_data_i,
	// output registers and feedback signals from other pipe stages
	.opcode_from_ID_i(opcode_decode_fetch),
	.rd_from_ID_i    (rd_decode_fetch),
	.pc_o            (pc_fetch_decode),
	.keep_o          (keep_fetch_decode),
	.rs1_o           (rs1_fetch_decode),
	.rs2_o           (rs2_fetch_decode),
	.rd_o            (rd_fetch_decode),
	.funct3_o        (funct3_fetch_decode),
	.funct7_o        (funct7_fetch_decode),
	.imm_o           (imm_fetch_decode),
	.opcode_o        (opcode_fetch_decode)
);
assign rd_decode_fetch = rd_decode_alu;
assign opcode_decode_fetch = opcode_decode_alu;

q100_decode u_decode(
    .clk,
	// instruction from fetch module
	.pc_i      (pc_fetch_decode),
	.keep_i    (keep_fetch_decode),
	.rs1_i     (rs1_fetch_decode),
	.rs2_i     (rs2_fetch_decode),
	.rd_i      (rd_fetch_decode),
	.funct3_i  (funct3_fetch_decode),
	.funct7_i  (funct7_fetch_decode),
	.imm_i     (imm_fetch_decode),
	.opcode_i  (opcode_fetch_decode),
	// register access
	.xn_i           (xn_reg_decode),
	.rd_WB_i        (rd_wb_decode),
	.xn_result_WB_i (xn_result_wb_decode),
	.reg_wr_WB_i    (reg_wr_wb_decode),
	// decode result to EX
	.WB_o        (WB_decode_alu),
	.CSR_o       (CSR_decode_alu),
	.M_o         (M_decode_alu),
	.EX_o        (EX_decode_alu),
	.pc_o        (pc_decode_alu),
	.xn_rs1_o    (xn_rs1_decode_alu),
	.xn_rs2_o    (xn_rs2_decode_alu),
	.rs1_o       (rs1_decode_alu),
	.rs2_o       (rs2_decode_alu),
	.rd_o        (rd_decode_alu),
	.funct3_o    (funct3_decode_alu),
	.funct7_o    (funct7_decode_alu),
	.opcode_o    (opcode_decode_alu),
	.imm_o       (imm_decode_alu)
);
assign xn_result_wb_decode = xn_result_wb_alu;
assign rd_wb_decode = rd_wb_alu;
assign reg_wr_wb_decode = reg_wr_wb_alu;

q100_alu u_alu(
    .clk,
	// decode result
	.WB_i      (WB_decode_alu),
	.CSR_i     (CSR_decode_alu),
	.M_i       (M_decode_alu),
	.EX_i      (EX_decode_alu),
	.pc_i      (pc_decode_alu),
	.xn_rs1_i  (xn_rs1_decode_alu),
	.xn_rs2_i  (xn_rs2_decode_alu),
	.rs1_i     (rs1_decode_alu),
	.rs2_i     (rs2_decode_alu),
	.rd_i      (rd_decode_alu),
	.funct3_i  (funct3_decode_alu),
	.funct7_i  (funct7_decode_alu),
	.opcode_i  (opcode_decode_alu),
	.imm_i     (imm_decode_alu),
	// pc flushing signal to IF
	.pc_flush_o     (pc_flush_alu_fetch),
	.pc_flush_vld_o (pc_flush_vld_alu_fetch),
	// bypass data from WB
    .WB_result_i(xn_result_wb_alu),
	.WB_reg_wr_i(reg_wr_wb_alu),
	.WB_rd_i    (rd_wb_alu),
	// alu result to MEM
	.WB_o        (WB_alu_mem),
	.CSR_o       (CSR_alu_mem),
	.M_o         (M_alu_mem),
	.reg_wr_o    (reg_wr_alu_mem),
	.alu_result_o(alu_result_alu_mem),
	.csr_value_o (csr_value_alu_mem),
	.csr_addr_o  (csr_addr_alu_mem),
	.rd_o        (rd_alu_mem),
	.xn_rs2_o    (xn_rs2_alu_mem),
	.funct3_o    (funct3_alu_mem),
	.funct7_o    (funct7_alu_mem),
	.opcode_o    (opcode_alu_mem)
);

q100_mem u_mem(
    .clk,
	// alu result
	.WB_i        (WB_alu_mem),
	.CSR_i       (CSR_alu_mem),
	.M_i         (M_alu_mem),
	.reg_wr_i    (reg_wr_alu_mem),
	.alu_result_i(alu_result_alu_mem),
	.csr_value_i (csr_value_alu_mem),
	.csr_addr_i  (csr_addr_alu_mem),
	.rd_i        (rd_alu_mem),
	.xn_rs2_i    (xn_rs2_alu_mem),
	.funct3_i    (funct3_alu_mem),
	.funct7_i    (funct7_alu_mem),
	.opcode_i    (opcode_alu_mem),
	// interface to memory
    .dtcm_rw_addr_o (dtcm_addr_o),
	.dtcm_rd_data_i (dtcm_data_i),
	.dtcm_wr_data_o (dtcm_data_o),
	.dtcm_rw_en_o   (dtcm_we_o), // 1 is write, 0 is read
	// mem result to WB
	.WB_o           (WB_mem_wb),
	.CSR_o          (CSR_mem_wb),
	.csr_value_o    (csr_value_mem_wb),
	.csr_addr_o     (csr_addr_mem_wb),
	.opcode_o       (opcode_mem_wb),
	.dtcm_rd_data_o (dtcm_rd_data_mem_wb),
	.alu_result_o   (alu_result_mem_wb),
	.wb_sel_o       (wb_sel_mem_wb),
	.rd_o           (rd_mem_wb)
);

q100_wb u_wb(
    .clk,	
	// mem result
	.WB_i           (WB_mem_wb),
	.CSR_i          (CSR_mem_wb),
	.csr_value_i    (csr_value_mem_wb),
	.csr_addr_i     (csr_addr_mem_wb),
	.opcode_i       (opcode_mem_wb),
	.dtcm_rd_data_i (dtcm_rd_data_mem_wb),
	.alu_result_i   (alu_result_mem_wb),
	.wb_sel_i       (wb_sel_mem_wb),
	.rd_i           (rd_mem_wb),
	// data write into registers
	.csr_value_o    (csr_value_wb_csr),
	.csr_addr_o     (csr_addr_wb_csr),
	.csr_vld_o      (csr_vld_wb_csr),
    .xn_result_o    (xn_result_wb_reg),
	.xn_wr_en_o     (xn_wr_en_wb_reg),
	.reg_wr         (reg_wr_wb_alu),
	.rd_o           (rd_wb_alu)
);
assign xn_result_wb_alu = xn_result_wb_reg;

q100_exu_registers u_registers(
    .clk,
	.rst,
	
	.xn_o     (xn_reg_decode),
	.xn_i     (xn_result_wb_reg),
	.xn_i_vld (xn_wr_en_wb_reg)
);

q100_exu_csr u_csr(
    .clk,
	.rst,
	
    .csr_i     (csr_value_wb_csr),
	.csr_o     (),
	.csr_addr_i(csr_addr_wb_csr),
	.csr_vld_i (csr_vld_wb_csr),
	
	// special controlled signals
	.done_intr (done_intr_o)
);

endmodule
