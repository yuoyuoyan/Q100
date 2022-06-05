// Author     : Qi Wang
// Date       : 1/2/2020
// Description: This module is DSP core for multi channel mode
//              MultiChan is the multi-channel design, multi dimension will be defined as different channels and not increase the DSP usage
module fir_multi_chan #(
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
logic tap_loop_en;
always_ff @(posedge clk)
  if(reset) tap[0][0] <= 'h0;
  else if(tap_vld_i) tap[0][0] <= tap_i;
  else if(tap_loop_en) tap[0][0] <= tap[0][TAP_COL-1];

generate
  for(genvar i=1; i<TAP_ROW; i++) begin : tap_buf_input
    always_ff @(posedge clk)
	  if(reset) tap[i][0] <= '0;
	  else if(tap_vld_i) tap[i][0] <= tap[i-1][TAP_COL-1];
	  else if(tap_loop_en) tap[i][0] <= tap[i][TAP_COL-1];
  end
  for(genvar i=0; i<TAP_ROW; i++) begin : tap_buf_row
    for(genvar j=1; j<TAP_COL; j++) begin : tap_buf_col
	  always_ff @(posedge clk)
	    if(tap_vld_i | tap_loop_en)
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
logic data_initial_load, data_load_en;
always_ff @(posedge clk)
  if(reset) data_fifo_dout_rdy <= 1'b0;
  else if(data_initial_load | data_load_en) data_fifo_dout_rdy <= 1'b1;
  else data_fifo_dout_rdy <= 1'b0;

logic data_fifo_dout_rdy_d;
always_ff @(posedge clk) data_fifo_dout_rdy_d <= data_fifo_dout_rdy;
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

// Data initial loading
localparam VLD_DELAY = TAP_ROW * TAP_ROW * TAP_COL;
logic [9:0] count_initial;
logic [VLD_DELAY-1:0] data_fifo_dout_vld_d;
always_ff @(posedge clk) data_fifo_dout_vld_d <= {data_fifo_dout_vld_d[VLD_DELAY-2:0], data_fifo_dout_vld};
localparam INITIAL_LOAD_LEN = (TAP_ROW-1)*DATA_COL+1;
always_ff @(posedge clk) begin
  if(reset) begin
    count_initial <= 10'd0;
	data_initial_load <= 1'b0;
  end
  else if(data_fifo_dout_vld) begin
    if(count_initial < INITIAL_LOAD_LEN) begin
      count_initial <= count_initial + 10'd1;
	  data_initial_load <= 1'b1;
	end
	else begin
	  data_initial_load <= 1'b0;
	end
  end
  else data_initial_load <= 1'b0;
end

// Data delay in the middle of DSP
logic [DATA_WIDTH-1:0] data_delay[TAP_COL-1:0][TAP_ROW:0];
logic [1:0] data_initial_load_d;
logic [7:0] count_chan;
always_ff @(posedge clk) data_initial_load_d <= {data_initial_load_d[0], data_initial_load};
always_ff @(posedge clk) begin
  if(reset) begin
    count_chan <= TAP_ROW-1;
	data_load_en <= 1'b0;
  end
  else if(data_fifo_dout_vld_d[0] & (!data_initial_load_d[1])) begin
    if(count_chan == 0) count_chan <= TAP_ROW-1;
	else count_chan <= count_chan - 8'd1;
    if(count_chan == 2) data_load_en <= 1'b1;
	else data_load_en <= 1'b0;
  end
  else begin
    count_chan <= TAP_ROW-1;
	data_load_en <= 1'b0;
  end
  if( (data_fifo_dout_vld | data_fifo_dout_vld_d[3]) & (!data_initial_load_d[1]))
    data_delay[0][0] <= data_buf[count_chan][0];
  
  if(reset) tap_loop_en <= 1'b0;
  else if(data_fifo_dout_vld_d[2] & (!data_initial_load_d[1])) tap_loop_en <= 1'b1;
  else tap_loop_en <= 1'b0;
end

generate
  for(genvar i=1; i<TAP_COL; i++) begin : data_delay_input
    always_ff @(posedge clk)
	  //if(data_fifo_dout_vld & (!data_initial_load))
	    data_delay[i][0] <= data_delay[i-1][TAP_ROW];
  end
  for(genvar i=0; i<TAP_COL; i++) begin : data_delay_pipes
    for(genvar j=1; j<TAP_ROW+1; j++) begin : data_delay_inpipe
	  always_ff @(posedge clk)
	    //if(data_fifo_dout_vld & (!data_initial_load))
		  data_delay[i][j] <= data_delay[i][j-1];
	end
  end
endgenerate

// Delay the tap to each DSP
logic [TAP_WIDTH-1:0] tap_delay[TAP_ROW-1:0][TAP_COL-1:0];
generate
  for(genvar i=0; i<TAP_ROW; i++) begin : tap_delay_row
    always_ff @(posedge clk)
	  tap_delay[i][0] <= tap[i][TAP_COL-1];
	for(genvar j=1; j<TAP_COL; j++) begin : tap_delay_col
	  always_ff @(posedge clk)
	    tap_delay[i][j] <= tap_delay[i][j-1];
	end
  end
endgenerate

// DSP part
logic [26:0] A[TAP_COL-1:0];
logic [17:0] B[TAP_COL-1:0];
logic [47:0] M[TAP_COL-1:0];
logic [47:0] P[TAP_COL-1:0];
logic [47:0] PCOUT[TAP_COL-1:0];
logic [47:0] PCIN[TAP_COL-1:0];

// DSP0
always_ff @(posedge clk) begin
  if( (data_fifo_dout_vld | data_fifo_dout_vld_d[VLD_DELAY-1]) & (!data_initial_load)) A[0] <= $signed(data_delay[0][TAP_ROW]);
  else A[0] <= 0;
  B[0] <= $signed(tap[0][TAP_COL-1]);
  M[0] <= $signed(A[0]) * $signed(B[0]);
  P[0] <= M[0];
  PCOUT[0] <= M[0];
end

// DSP1-(end-1)
generate
  for(genvar i=1; i<TAP_ROW-1; i++) begin : DSP_chain
    assign PCIN[i] = PCOUT[i-1];
    always_ff @(posedge clk) begin
	  if( (data_fifo_dout_vld | data_fifo_dout_vld_d[VLD_DELAY-1]) & (!data_initial_load)) A[i] <= $signed(data_delay[i][TAP_ROW]);
	  B[i] <= $signed(tap_delay[i][i-1]);
	  M[i] <= $signed(A[i]) * $signed(B[i]);
	  P[i] <= PCIN[i] + M[i];
	  PCOUT[i] <= PCIN[i] + M[i];
	end
  end
endgenerate

// accumulation loop
logic OPMODE;
logic [1:0] OPMODE_d;
always_ff @(posedge clk)
  if(reset) OPMODE <= 1'b0;
  else if(count_chan==0) OPMODE <= 1'b0;
  else OPMODE <= 1'b1;
always_ff @(posedge clk)
  OPMODE_d <= {OPMODE_d[0], OPMODE};

// DSP end
assign PCIN[TAP_COL-1] = PCOUT[TAP_COL-2];
always_ff @(posedge clk) begin
  if( (data_fifo_dout_vld | data_fifo_dout_vld_d[VLD_DELAY-1]) & (!data_initial_load)) A[TAP_COL-1] <= $signed(data_delay[TAP_COL-1][TAP_ROW]);
  B[TAP_COL-1] <= $signed(tap_delay[TAP_ROW-1][TAP_ROW-2]);
  M[TAP_COL-1] <= $signed(A[TAP_COL-1]) * $signed(B[TAP_COL-1]);
  P[TAP_COL-1] <= (OPMODE_d[1]) ? P[TAP_COL-1] + PCIN[TAP_COL-1] + M[TAP_COL-1] : PCIN[TAP_COL-1] + M[TAP_COL-1];
  //P[TAP_COL-1] <= PCIN[TAP_COL-1] + M[TAP_COL-1];
end

// result output logic
localparam DATA_START = (TAP_ROW+1)*TAP_COL+TAP_ROW+2;
localparam DATA_END = 3*(DATA_ROW*DATA_COL + DATA_START);
localparam DATA_LEN_COL = DATA_COL-TAP_COL+1;
logic [15:0] result_count;
logic [7:0]  result_loop_count, result_row_count, result_col_count;
always_ff @(posedge clk) begin
  if(reset) result_count <= 16'd0;
  else if(data_fifo_dout_vld & (!data_initial_load)) result_count <= result_count + 16'd1;
  
  if( (result_count>DATA_START) & (result_count<DATA_END) ) begin
    result_o <= P[TAP_COL-1][31:0];
  end
  
  if(reset) begin
    result_loop_count <= 8'd0;
	result_row_count <= 8'd0;
	result_col_count <= 8'd0;
	result_vld_o <= 1'b0;
  end
  else if( (result_count > DATA_START) & (result_count<DATA_END) ) begin
    if(result_loop_count==TAP_ROW-1) result_loop_count <= 8'd0;
	else result_loop_count <= result_loop_count + 8'd1;
	if(result_loop_count==TAP_ROW-1) begin
	  if(result_col_count < DATA_LEN_COL) result_vld_o <= 1'b1;
	  if(result_col_count == DATA_COL-1) result_col_count <= 8'd0;
	  else result_col_count <= result_col_count + 8'd1;
	end
	else result_vld_o <= 1'b0;
  end
  else 
    result_vld_o <= 1'b0;
  
  if(result_count==DATA_END) result_finish_o <= 1'b1;
  else result_finish_o <= 1'b0;
end

endmodule
