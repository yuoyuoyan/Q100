// Author     : Qi Wang
// Date       : 1/4/2020
// Description: This module is DSP core for DSP matrix mode
//              DSPMatrix is the DSP matrix and adder tree design, ignore the DSP usage and get it done ASAP
module fir_dsp_matrix #(
  parameter TAP_ROW = 3,
  parameter TAP_COL = 3,	
  parameter TAP_WIDTH = 8,
  parameter DATA_ROW = 16,
  parameter DATA_COL = 16,
  parameter DATA_WIDTH = 16
) 
(
  input clk,
  input reset,
  
  input  logic [TAP_WIDTH-1:0]  tap_i,
  input  logic                  tap_vld_i,
  input  logic [DATA_WIDTH-1:0] data_i,
  input  logic                  data_vld_i,
  output logic [31:0]           result_o,
  output logic                  result_vld_o,
  output logic                  result_finish_o
);

// tap buffer
logic [TAP_WIDTH-1:0] tap[TAP_ROW-1:0][TAP_COL-1:0];
always_ff @(posedge clk)
  if(reset) tap[0][0] <= 'h0;
  else if(tap_vld_i) tap[0][0] <= tap_i;

generate
  for(genvar i=1; i<TAP_ROW; i++) begin : tap_buf_input
    always_ff @(posedge clk)
	  if(reset) tap[i][0] <= '0;
	  else if(tap_vld_i) tap[i][0] <= tap[i-1][TAP_COL-1];
  end
  for(genvar i=0; i<TAP_ROW; i++) begin : tap_buf_row
    for(genvar j=1; j<TAP_COL; j++) begin : tap_buf_col
	  always_ff @(posedge clk)
	    if(tap_vld_i)
	      tap[i][j] <= tap[i][j-1];
	end
  end
endgenerate

// Delay the data vld, to stuff unused data at the end
logic [DATA_COL-1:0] data_vld_i_delay;
always_ff @(posedge clk) data_vld_i_delay <= {data_vld_i_delay[DATA_COL-2:0], data_vld_i};

// FIFO to store the r/w address and data written from external source
logic [DATA_WIDTH-1:0] data_fifo_din, data_fifo_dout;
logic        data_fifo_din_vld, data_fifo_dout_vld, data_fifo_dout_rdy;
assign data_fifo_din_vld = data_vld_i | data_vld_i_delay[DATA_COL-1];
assign data_fifo_din = (data_vld_i | data_vld_i_delay[DATA_COL-1]) ? data_i : 0;
fir_fifo #(
  .WIDTH(DATA_WIDTH),
  .DEPTH(256)
)
data_fifo(
  .clk(clk),
  .reset(reset),
  .din(data_fifo_din),
  .din_vld(data_fifo_din_vld),
  .din_rdy(),
  .almost_full(),
  .dout(data_fifo_dout),
  .dout_vld(data_fifo_dout_vld),
  .dout_rdy(data_fifo_dout_rdy),
  .almost_empty()
);

// Data buffer to filters
logic [DATA_WIDTH-1:0] data_buf[TAP_ROW-1:0][DATA_COL-1:0];
always_ff @(posedge clk)
  if(reset) data_fifo_dout_rdy <= 1'b0;
  else if(data_fifo_dout_vld) data_fifo_dout_rdy <= 1'b1;
  else data_fifo_dout_rdy <= 1'b0;

always_ff @(posedge clk)
  if(reset)
    data_buf[0][0] <= 0;
  else if(data_fifo_dout_rdy)
    data_buf[0][0] <= data_fifo_dout;

generate
  for(genvar i=1; i<TAP_ROW; i++) begin : data_buf_input
    always_ff @(posedge clk)
	  if(reset) data_buf[i][0] <= '0;
	  else if(data_fifo_dout_rdy) data_buf[i][0] <= data_buf[i-1][DATA_COL-1];
  end
  for(genvar i=0; i<TAP_ROW; i++) begin : data_buf_row
    for(genvar j=1; j<DATA_COL; j++) begin : data_buf_col
	  always_ff @(posedge clk)
	    if(data_fifo_dout_rdy)
	      data_buf[i][j] <= data_buf[i][j-1];
	end
  end
endgenerate

// DSP matrix part
localparam DSP_NUM = TAP_ROW * TAP_COL;
logic [26:0] A[TAP_ROW-1:0][TAP_COL-1:0];
logic [26:0] ACOUT[TAP_ROW-1:0][TAP_COL-1:0];
logic [26:0] ACIN[TAP_ROW-1:0][TAP_COL-1:0];
logic [17:0] B[TAP_ROW-1:0][TAP_COL-1:0];
logic [47:0] M[TAP_ROW-1:0][TAP_COL-1:0];
logic [47:0] P[TAP_ROW-1:0][TAP_COL-1:0];
logic [47:0] PCOUT[TAP_ROW-1:0][TAP_COL-1:0];
logic [47:0] PCIN[TAP_ROW-1:0][TAP_COL-1:0];

generate
  for(genvar i=0; i<TAP_ROW; i++) begin : DSP_ROW
    always_ff @(posedge clk) begin
	  A[i][0] <= $signed(data_buf[i][DATA_COL-1]);
	  ACOUT[i][0] <= A[i][0];
	  B[i][0] <= $signed(tap[0][i]);
	  M[i][0] <= $signed(A[i][0]) * $signed(B[i][0]);
	  P[i][0] <= M[i][0];
	  PCOUT[i][0] <= M[i][0];
	end
    for(genvar j=1; j<TAP_COL; j++) begin : DSP_COL
	  assign ACIN[i][j] = ACOUT[i][j-1];
	  assign PCIN[i][j] = PCOUT[i][j-1];
	  always_ff @(posedge clk) begin
	    A[i][j] <= ACIN[i][j];
		ACOUT[i][j] <= A[i][j];
		B[i][j] <= $signed(tap[j][i]);
		M[i][j] <= $signed(A[i][j]) * $signed(B[i][j]);
		P[i][j] <= M[i][j] + PCIN[i][j];
		PCOUT[i][j] <= M[i][j] + PCIN[i][j];
	  end
	end
  end
endgenerate

// Adder tree after DSP matrix
localparam TREE_DEPTH = $clog2(TAP_ROW);
localparam TREE_WIDTH = 2**TREE_DEPTH;
logic [31:0] adder[TREE_DEPTH:0][TREE_WIDTH-1:0];
generate
  for(genvar i=0; i<TREE_DEPTH; i++) begin : adder_tree_row
    localparam TREE_WIDTH_REAL = 2**i;
    for(genvar j=0; j<TREE_WIDTH_REAL; j++) begin : adder_tree_col
	  always_ff @(posedge clk)
	    adder[i][j] <= adder[i+1][2*j] + adder[i+1][2*j+1];
	end
  end
  
  for(genvar j=0; j<TREE_WIDTH; j++) begin : adder_load
    if(j<TAP_ROW)
	  always_ff @(posedge clk)
	    adder[TREE_DEPTH][j] <= P[j][TAP_COL-1][31:0];
	else
	  always_ff @(posedge clk)
	    adder[TREE_DEPTH][j] <= 32'h0;
  end
endgenerate

// Result sending logic
localparam DELAY_NUM = TREE_DEPTH + 2*TAP_COL + TAP_ROW*DATA_COL + 3;
localparam DATA_END = (DATA_ROW-TAP_ROW+1) * DATA_COL;
logic [DELAY_NUM-1:0] data_fifo_dout_vld_delay;
logic [9:0] count_result, count_row, count_col;
always_ff @(posedge clk)
  data_fifo_dout_vld_delay <= {data_fifo_dout_vld_delay[DELAY_NUM-2:0], data_fifo_dout_vld};

always_ff @(posedge clk) begin
  if(reset) begin
    count_result <= 10'd0;
	count_row <= 10'd0;
	count_col <= 10'd0;
	result_finish_o <= 1'b0;
  end
  else if(data_fifo_dout_vld_delay[DELAY_NUM-1]) begin
    count_result <= count_result + 10'd1;
	if(count_result==DATA_END)
	  result_finish_o <= 1'b1;
	else
	  result_finish_o <= 1'b0;
	
    if(count_col==DATA_COL-1) begin
	  count_col <= 10'd0;
	  count_row <= count_row + 10'd1;
	end
	else begin
	  count_col <= count_col + 10'd1;
	end
	
	if( (count_col < (DATA_COL-TAP_COL+1)) & (count_row < (DATA_ROW-TAP_ROW+1)) ) begin
	  result_vld_o <= 1'b1;
	end
	else begin
	  result_vld_o <= 1'b0;
	end
	
	result_o <= adder[0][0];
  end
  else begin
    result_finish_o <= 1'b0;
	result_vld_o <= 1'b0;
  end
end

endmodule
