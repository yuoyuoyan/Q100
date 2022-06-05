// Q100 core module, including EXU, ITCM and DTCM
`include "q100_config.svh"
module q100_core #(
    parameter EXT_DTCM = 1,
	parameter EXT_ITCM = 0
)
(
    input clk,
	input rst,
	
	// Interface to the external ITCM and DTCM if used
    output [`ITCM_ADDR_WIDTH-1:0] itcm_addr_o,
    output                        itcm_we_o,
    output [`ITCM_DATA_WIDTH-1:0] itcm_dout_o,
    input  [`ITCM_DATA_WIDTH-1:0] itcm_din_i,
	
    output [`DTCM_ADDR_WIDTH-1:0] dtcm_addr_o,
    output [`DTCM_BANK-1:0]       dtcm_we_o,
    output [`DTCM_DATA_WIDTH-1:0] dtcm_dout_o,
    input  [`DTCM_DATA_WIDTH-1:0] dtcm_din_i,
	
	// done interrupt
	output                        done_intr_o
);

logic [`ITCM_ADDR_WIDTH-1:0] itcm_addr_exu_itcm;
logic                        itcm_we_exu_itcm;
logic [`ITCM_DATA_WIDTH-1:0] itcm_data_exu_itcm;
logic [`ITCM_DATA_WIDTH-1:0] itcm_data_itcm_exu;

logic [`DTCM_ADDR_WIDTH-1:0] dtcm_addr_exu_dtcm;
logic [`DTCM_BANK-1:0]       dtcm_we_exu_dtcm;
logic [`DTCM_DATA_WIDTH-1:0] dtcm_data_exu_dtcm;
logic [`DTCM_DATA_WIDTH-1:0] dtcm_data_dtcm_exu;

q100_exu u_exu(
    .clk,
	.rst,
	
	// To itcm
	.itcm_addr_o  (itcm_addr_exu_itcm),
	.itcm_we_o    (itcm_we_exu_itcm),
	.itcm_data_i  (itcm_data_itcm_exu),
	.itcm_data_o  (itcm_data_exu_itcm),
	
	// To dtcm
	.dtcm_addr_o  (dtcm_addr_exu_dtcm),
	.dtcm_we_o    (dtcm_we_exu_dtcm),
	.dtcm_data_i  (dtcm_data_dtcm_exu),
	.dtcm_data_o  (dtcm_data_exu_dtcm),
	
	// Special signal
	.done_intr_o  (done_intr_o)
);

generate
    if(EXT_ITCM==0) begin : use_internal_itcm
	    logic [`ITCM_ADDR_WIDTH-1:0] itcm_addr_to_itcm;
        logic                        itcm_we_to_itcm;
        logic [`ITCM_DATA_WIDTH-1:0] itcm_data_to_itcm;
        logic [`ITCM_DATA_WIDTH-1:0] itcm_data_from_itcm;
        
        assign itcm_we_to_itcm = itcm_we_exu_itcm;
        assign itcm_addr_to_itcm = itcm_addr_exu_itcm;
        assign itcm_data_to_itcm = itcm_data_exu_itcm;
        assign itcm_data_itcm_exu = itcm_data_from_itcm;
        q100_itcm #(
            .ITCM_DATA_WIDTH(`ITCM_DATA_WIDTH),
            .ITCM_ADDR_WIDTH(`ITCM_ADDR_WIDTH),
            .INIT_FILE("")
        )
        u_itcm
        (
            .clk,
            .rst,
            
            .itcm_addr_i  (itcm_addr_to_itcm[11:0]),
            .itcm_we_i    (itcm_we_to_itcm),
            .itcm_data_o  (itcm_data_from_itcm),
            .itcm_data_i  (itcm_data_to_itcm)
        );
	end
	else begin : use_external_itcm
	    assign itcm_addr_o = itcm_addr_exu_itcm;
		assign itcm_we_o = itcm_we_exu_itcm;
		assign itcm_dout_o = itcm_data_exu_itcm;
		assign itcm_data_itcm_exu = itcm_din_i;
	end
endgenerate



generate
    if(EXT_DTCM==0) begin : use_internal_dtcm
	    logic [`DTCM_ADDR_WIDTH-1:0] dtcm_addr_to_dtcm;
        logic [`DTCM_BANK-1:0]       dtcm_we_to_dtcm;
        logic [`DTCM_DATA_WIDTH-1:0] dtcm_data_to_dtcm;
        logic [`DTCM_DATA_WIDTH-1:0] dtcm_data_from_dtcm;
        
        assign dtcm_we_to_dtcm = dtcm_we_exu_dtcm;
        assign dtcm_addr_to_dtcm = dtcm_addr_exu_dtcm;
        assign dtcm_data_to_dtcm = dtcm_data_exu_dtcm;
        assign dtcm_data_dtcm_exu = dtcm_data_from_dtcm;
		
        q100_dtcm #(
            .DTCM_DATA_WIDTH(`DTCM_DATA_WIDTH),
        	.DTCM_ADDR_WIDTH(`DTCM_ADDR_WIDTH),
        	.DTCM_BANK(`DTCM_BANK),
        	.INIT_FILE("")
        )
        u_dtcm
        (
            .clk,
        	.rst,
        	.dtcm_addr_i  (dtcm_addr_to_dtcm[11:0]),
        	.dtcm_we_i    (dtcm_we_to_dtcm),
        	.dtcm_data_o  (dtcm_data_from_dtcm),
        	.dtcm_data_i  (dtcm_data_to_dtcm)
        );
    end
	else begin : use_external_dtcm
	    assign dtcm_addr_o = dtcm_addr_exu_dtcm;
		assign dtcm_we_o = dtcm_we_exu_dtcm;
		assign dtcm_dout_o = dtcm_data_exu_dtcm;
		assign dtcm_data_dtcm_exu = dtcm_din_i;
	end
endgenerate

endmodule
