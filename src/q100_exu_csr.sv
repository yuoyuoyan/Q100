// CSR module
`include "q100_config.svh"
module q100_exu_csr(
    input clk,
	input rst,
	
    input        [`LEN_CSR-1:0]      csr_i,
	output logic [`LEN_CSR-1:0]      csr_o,
	input        [`LEN_CSR_ADDR-1:0] csr_addr_i,
	input                            csr_vld_i,
	
	// special controlled signals
	output logic done_intr
);

logic [31:0] mtvec;
logic [31:0] mepc;
logic [31:0] mcause;
logic [31:0] mie;
logic [31:0] mip;
logic [31:0] mtval;
logic [31:0] mscratch;
logic [31:0] mstatus;
logic [31:0] done_status;
always_ff @(posedge clk)
    if(rst) done_status <= 0;
	else if(csr_vld_i && (csr_addr_i==`CSR_DONE_STATUS)) done_status <= csr_i;

always_comb begin
    case(csr_addr_i)
	`CSR_DONE_STATUS: csr_o = done_status;
	default: csr_o = 0;
	endcase
end
	
// Special control signal
assign done_intr = done_status[0];

endmodule
