// key registers module
// currently implement RV32I only
// x0 / zero    Hardwired zero
// x1 / ra      Return address
// x2 / sp      Stack pointer
// x3 / gp      Global pointer
// x4 / tp      Thread pointer
// x5 / t0      Temporary
// x6 / t1      Temporary
// x7 / t2      Temporary
// x8 / x0 / fp Saved register, frame pointer
// x9 / s1      Saved regsiter
// x10/ a0      Function argument, return value
// x11/ a1      Function argument, return value
// x12/ a2      Function argument
// x13/ a3      Function argument
// x14/ a4      Function argument
// x15/ a5      Function argument
// x16/ a6      Function argument
// x17/ a7      Function argument
// x18/ s2      Saved regsiter
// x19/ s3      Saved regsiter
// x20/ s4      Saved regsiter
// x21/ s5      Saved regsiter
// x22/ s6      Saved regsiter
// x23/ s7      Saved regsiter
// x24/ s8      Saved regsiter
// x25/ s9      Saved regsiter
// x26/ s10     Saved regsiter
// x27/ s11     Saved regsiter
// x28/ t3      Temporary
// x29/ t4      Temporary
// x30/ t5      Temporary
// x31/ t6      Temporary
`include "q100_config.svh"
module q100_exu_registers(
    input clk,
	input rst,
	
	output [`LEN_REG-1:0][`LEN_REG_VAL-1:0] xn_o,
	input  [`LEN_REG_VAL-1:0]               xn_i,
	input  [`LEN_REG-1:0]                   xn_i_vld
);

// list all registers
assign x0_zero = `LEN_REG_VAL'h0;
assign xn_o[0] = `LEN_REG_VAL'h0;

logic [`LEN_REG_VAL-1:0] xn[`LEN_REG-1:0];
generate
    for(genvar i=1; i<32; i++) begin : key_registers
	    always_ff @(posedge clk)
		    if(rst)
			    xn[i] <= 0;
			else if(xn_i_vld[i])
			    xn[i] <= xn_i;
		assign xn_o[i] = xn[i];
	end
endgenerate

endmodule
