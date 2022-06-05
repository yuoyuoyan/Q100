// Author     : Qi Wang
// Date       : 12/10/2020
// Description: This module is DSP core for Single DSP mode
//              Single DSP is used to do multiplication and accumulation, and eventually send out data
//              Single is the single-DSP design, all dimensions will be realized in single DSP, reduce the DSP usage
module fir_single_dsp (
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
localparam DATA_NUM = 65536;
localparam DATA_WIDTH = 16;

// Two loop storage for tap and data, looping until it finishs
logic [TAP_WIDTH-1:0] tap_loop[TAP_NUM:0];
logic [DATA_WIDTH-1:0] data_loop[TAP_NUM-1:0];

always_ff @(posedge clk) begin
  if(rst) begin
    tap_loop[0] <= 'd0;
    tap_loop[1] <= 'd7;
    tap_loop[2] <= 'd24;
    tap_loop[3] <= 'd43;
    tap_loop[4] <= 'd55;
    tap_loop[5] <= 'd55;
    tap_loop[6] <= 'd43;
    tap_loop[7] <= 'd24;
    tap_loop[8] <= 'd7;
    tap_loop[9] <= 'd0;
	tap_loop[10]<= 'd0;
  end
  else if(!done_intr) begin
    tap_loop[0] <= tap_loop[10];
    tap_loop[1] <= tap_loop[0];
    tap_loop[2] <= tap_loop[1];
    tap_loop[3] <= tap_loop[2];
    tap_loop[4] <= tap_loop[3];
    tap_loop[5] <= tap_loop[4];
    tap_loop[6] <= tap_loop[5];
    tap_loop[7] <= tap_loop[6];
    tap_loop[8] <= tap_loop[7];
    tap_loop[9] <= tap_loop[8];
	tap_loop[10]<= tap_loop[9];
  end
end
  
generate
  for(genvar i=1; i<TAP_NUM; i++) begin : looping
	always @(posedge clk) 
	  if(rst) data_loop[i] <= 0;
	  else if(!done_intr) data_loop[i] <= data_loop[i-1];
  end
endgenerate

// Get initial input data, and get new data when one loop is done
logic [7:0] count_loop;
logic [7:0] count_initial_load;
// read address control
always_ff @(posedge clk) begin
  if(rst) 
    data_addr_rd_o <= 0;
  else if((count_initial_load <= TAP_NUM) | (count_loop == TAP_NUM))
    data_addr_rd_o <= data_addr_rd_o + 1;
end

always_ff @(posedge clk) begin
  if(rst) begin
	count_loop <= 8'd0;
	count_initial_load <= 8'd0;
	data_loop[0] <= 'h0;
  end
  else if(count_initial_load <= TAP_NUM) begin
    count_initial_load <= count_initial_load + 8'd1;
	count_loop <= (count_loop == TAP_NUM) ? 8'd0 : count_loop + 8'd1;
	data_loop[0] <= data_din_i;
  end
  else if(!done_intr) begin
	count_loop <= (count_loop == TAP_NUM) ? 8'd0 : count_loop + 8'd1;
	data_loop[0] <= (count_loop == 0) ? data_din_i : data_loop[TAP_NUM-1];
  end
  else begin
    count_initial_load <= TAP_NUM;
	count_loop <= 8'd0;
  end
end

// Delay the loop counter for 2 clock cycles, to determine the DSP function mode
logic [26:0] A;
logic [17:0] B;
logic [47:0] M;
logic [47:0] P;
logic OPMODE;
logic [7:0] count_loop_d, count_loop_dd, count_loop_ddd;
always_ff @(posedge clk) begin
  count_loop_d <= count_loop;
  count_loop_dd <= count_loop_d;
  count_loop_ddd <= count_loop_dd;
  if( (count_loop_dd == 0) | (count_loop_dd == TAP_NUM)) OPMODE <= 1'b0;
  else OPMODE <= 1'b1;
end

//logic [15:0] tap_d;
//always_ff @(posedge clk)
//  tap_d <= tap_loop[0];

// DSP part
always_ff @(posedge clk) begin
  A <= {{(27-DATA_WIDTH){data_loop[0][DATA_WIDTH-1]}}, data_loop[0]};
  B <= {{(18-TAP_WIDTH){tap_loop[0][TAP_WIDTH-1]}}, tap_loop[0]};
  M <= $signed(A) * $signed(B);
  P <= (OPMODE==1'b1) ? (P+M) : M;
end

// result output logic
// Count the result output, and send out finish signal
logic [16:0] count_result;
always_ff @(posedge clk) begin
  if(rst) begin
    data_dout_o <= 16'h0;
    data_we_o <= 1'b0;
	data_addr_wr_o <= 16'hffff;
	count_result <= 'd0;
	done_intr <= 1'b0;
  end
  else if(count_loop_ddd == TAP_NUM) begin
    data_dout_o <= P[23:8];
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
