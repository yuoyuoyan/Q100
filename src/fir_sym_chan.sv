// Author     : Qi Wang
// Date       : 1/1/2021
// Description: This module is DSP core for symmetrical channel mode
//              SymChan is the single-symmetric-channel design, cast to 1 dimension, only works for symmetrical FIR design
module fir_sym_chan (
  input clk,
  input rst,
  
  output logic [15:0] data_addr_rd_o,
  output logic [15:0] data_addr_wr_o,
  input  logic [15:0] data_din_i,
  output logic [15:0] data_dout_o,
  output logic        data_we_o,
  
  output logic        done_intr
);

localparam TAP_NUM = 10;
localparam TAP_WIDTH = 16;
localparam DATA_NUM = 256;
localparam DATA_WIDTH = 16;
localparam TAP_NUM_HALF = TAP_NUM >> 1;

// tap buffer
logic [TAP_WIDTH-1:0] tap[TAP_NUM_HALF-1:0];
always_ff @(posedge clk) begin
  if(rst) begin
    tap[0] <= 'd0;
    tap[1] <= 'd7;
    tap[2] <= 'd24;
    tap[3] <= 'd43;
    tap[4] <= 'd55;
  end
end


// Delay the data valid for all DSP level
logic [21:0] data_vld_d;
always_ff @(posedge clk)
  if(rst) data_vld_d <= 22'h0;
  else data_vld_d <= {data_vld_d[20:0], !done_intr};
  
// Delay the data input
logic [DATA_WIDTH-1:0] data[2*TAP_NUM-3:0];
always_ff @(posedge clk)
  if(rst) data[0] <= 'h0;
  else if(!done_intr) data[0] <= data_din_i;

// control the read address
always_ff @(posedge clk) begin
  if(rst) 
    data_addr_rd_o <= 0;
  else if(!done_intr)
    data_addr_rd_o <= data_addr_rd_o + 1;
end

generate
  for(genvar i=1; i<2*TAP_NUM-2; i++) begin : data_buf
    always_ff @(posedge clk)
	  if(rst) data[i] <= 'h0;
	  else data[i] <= data[i-1];
  end
endgenerate

// DSP part
logic [26:0] A[TAP_NUM_HALF-1:0];
logic [17:0] B[TAP_NUM_HALF-1:0];
logic [26:0] D[TAP_NUM_HALF-1:0];
logic [47:0] M[TAP_NUM_HALF-1:0];
logic [47:0] P[TAP_NUM_HALF-1:0];
logic [47:0] PCOUT[TAP_NUM_HALF-1:0];
logic [47:0] PCIN[TAP_NUM_HALF-1:0];
// DSP0
always_ff @(posedge clk) begin
  if(!done_intr) A[0] <= $signed(data_din_i);
  else A[0] <= 0;
  D[0] <= $signed(data[TAP_NUM-2]);
  B[0] <= tap[0];
  M[0] <= ($signed(A[0]) + $signed(D[0])) * $signed(B[0]);
  P[0] <= M[0];
  PCOUT[0] <= M[0];
end
// DSP1-(end-1)
generate
  for(genvar i=1; i<TAP_NUM_HALF-1; i++) begin : DSP_chain
    assign PCIN[i] = PCOUT[i-1];
    always_ff @(posedge clk) begin
	  A[i] <= $signed(data[2*i-1]);
	  D[i] <= $signed(data[TAP_NUM-2]);
	  B[i] <= tap[i];
	  M[i] <= ($signed(A[i]) + $signed(D[i])) * $signed(B[i]);
	  P[i] <= PCIN[i] + M[i];
	  PCOUT[i] <= PCIN[i] + M[i];
	end
  end
endgenerate
// DSP end
assign PCIN[TAP_NUM_HALF-1] = PCOUT[TAP_NUM_HALF-2];
always_ff @(posedge clk) begin
  A[TAP_NUM_HALF-1] <= $signed(data[2*TAP_NUM_HALF-3]);
  D[TAP_NUM_HALF-1] <= $signed(data[TAP_NUM-2]);
  B[TAP_NUM_HALF-1] <= tap[TAP_NUM_HALF-1];
  M[TAP_NUM_HALF-1] <= ($signed(A[TAP_NUM_HALF-1]) + $signed(D[TAP_NUM_HALF-1])) * $signed(B[TAP_NUM_HALF-1]);
  P[TAP_NUM_HALF-1] <= PCIN[TAP_NUM_HALF-1] + M[TAP_NUM_HALF-1];
end

// result output logic
logic [16:0] count_result;
always_ff @(posedge clk) begin
  if(rst) begin
    data_dout_o <= 16'h0;
    data_we_o <= 1'b0;
	data_addr_wr_o <= 16'hffff;
	count_result <= 'd0;
	done_intr <= 1'b0;
  end
  else if(data_vld_d[16] & !done_intr) begin
    data_dout_o <= P[TAP_NUM_HALF-1][23:8];
	data_we_o <= 1'b1;
	data_addr_wr_o <= data_addr_wr_o + 1;
    if(count_result==(DATA_NUM-1))
	  done_intr <= 1'b1;
	count_result <= count_result + 1;
  end
  else begin
    data_we_o <= 1'b0;
  end
end

endmodule
