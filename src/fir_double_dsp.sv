// Author     : Qi Wang
// Date       : 12/25/2020
// Description: This module is DSP core for Double DSP mode
//              Double is the double-DSP design, all dimensions will be realized in two DSPs, increase the DSP usage, but double speed of single DSP mode
module fir_double_dsp (
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
localparam TAP_NUM_HALF = TAP_NUM/2;

// Two loop storage for tap and data, looping until it finishs
logic [TAP_WIDTH-1:0] tap_loop0[TAP_NUM_HALF:0];
logic [TAP_WIDTH-1:0] tap_loop1[TAP_NUM_HALF:0];
logic [DATA_WIDTH-1:0] data_loop0[TAP_NUM_HALF-1:0];
logic [DATA_WIDTH-1:0] data_loop1[TAP_NUM_HALF-1:0];

// Looping of tap, until it finishs
always_ff @(posedge clk) begin
  if(rst) begin
    tap_loop0[0] <= 'd0;
    tap_loop0[1] <= 'd7;
    tap_loop0[2] <= 'd24;
    tap_loop0[3] <= 'd43;
    tap_loop0[4] <= 'd55;
	tap_loop0[5] <= 'd0;
	
    tap_loop1[0] <= 'd55;
    tap_loop1[1] <= 'd43;
    tap_loop1[2] <= 'd24;
    tap_loop1[3] <= 'd7;
    tap_loop1[4] <= 'd0;
	tap_loop1[5] <= 'd0;
  end
  else if(!done_intr) begin
    tap_loop0[0] <= tap_loop0[5];
    tap_loop0[1] <= tap_loop0[0];
    tap_loop0[2] <= tap_loop0[1];
    tap_loop0[3] <= tap_loop0[2];
    tap_loop0[4] <= tap_loop0[3];
    tap_loop0[5] <= tap_loop0[4];
	
    tap_loop1[0] <= tap_loop1[5];
    tap_loop1[1] <= tap_loop1[0];
    tap_loop1[2] <= tap_loop1[1];
    tap_loop1[3] <= tap_loop1[2];
	tap_loop1[4] <= tap_loop1[3];
	tap_loop1[5] <= tap_loop1[4];
  end
end

generate
  for(genvar i=1; i<TAP_NUM_HALF; i++) begin : data_looping0
	always @(posedge clk) 
	  if(rst) data_loop0[i] <= 0;
	  else if(!done_intr) data_loop0[i] <= data_loop0[i-1];
  end
endgenerate

generate
  for(genvar i=1; i<TAP_NUM_HALF; i++) begin : data_looping1
	always @(posedge clk) 
	  if(rst) data_loop1[i] <= 0;
	  else if(!done_intr) data_loop1[i] <= data_loop1[i-1];
  end
endgenerate

// Get initial input data, and get new data when one loop is done
logic [7:0] count_loop;
logic [7:0] count_initial_load;
// read address control
always_ff @(posedge clk) begin
  if(rst) 
    data_addr_rd_o <= 0;
  else if((count_initial_load < TAP_NUM) | (count_loop == TAP_NUM_HALF))
    data_addr_rd_o <= data_addr_rd_o + 1;
end

logic [7:0] count_loop_d, count_loop_dd, count_loop_ddd;
always_ff @(posedge clk) begin
  if(rst) begin
	count_loop <= 8'd0;
	count_initial_load <= 8'd0;
	data_loop0[0] <= 'h0;
	data_loop1[0] <= 'h0;
  end
  else if(count_initial_load <= TAP_NUM) begin
    count_initial_load <= count_initial_load + 8'd1;
	count_loop <= (count_loop == TAP_NUM_HALF) ? 8'd0 : count_loop + 8'd1;
	data_loop0[0] <= data_din_i;
	data_loop1[0] <= data_loop0[TAP_NUM_HALF-1];
  end
  else if(!done_intr) begin
	count_loop <= (count_loop == TAP_NUM_HALF) ? 8'd0 : count_loop + 8'd1;
	data_loop0[0] <= (count_loop == TAP_NUM_HALF) ? data_din_i : data_loop0[TAP_NUM_HALF-1];
	data_loop1[0] <= (count_loop == TAP_NUM_HALF) ? data_loop0[TAP_NUM_HALF-1] : data_loop1[TAP_NUM_HALF-1];
  end
end

// Delay the loop counter for 2 clock cycles, to determine the DSP function mode
logic [26:0] A0, A1, A1_d;
logic [17:0] B0, B1, B1_d;
logic [47:0] M0, M1;
logic [47:0] P0, P1;
logic [47:0] PCOUT0, PCIN1;
logic       OPMODE;
logic [1:0] OPMODE_d;
always_ff @(posedge clk) begin
  count_loop_d <= count_loop;
  count_loop_dd <= count_loop_d;
  count_loop_ddd <= count_loop_dd;
  if( (count_loop == 0) | (count_loop == TAP_NUM_HALF)) OPMODE <= 1'b0;
  else OPMODE <= 1'b1;
  if( (count_loop_d == 0) | (count_loop_d == TAP_NUM_HALF)) OPMODE_d <= 2'b00;
  else if(count_loop_d == TAP_NUM_HALF-1) OPMODE_d <= 2'b01;
  else OPMODE_d <= 2'b10;
end

// DSP0 part
always_ff @(posedge clk) begin
  A0 <= {{(27-DATA_WIDTH){data_loop0[TAP_NUM_HALF-1][DATA_WIDTH-1]}}, data_loop0[TAP_NUM_HALF-1]};
  B0 <= {{(18-TAP_WIDTH){tap_loop0[TAP_NUM_HALF-2][TAP_WIDTH-1]}}, tap_loop0[TAP_NUM_HALF-2]};
  M0 <= $signed(A0) * $signed(B0);
  P0 <= (OPMODE==1'b1) ? (P0+M0) : M0;
  PCOUT0 <= (OPMODE==1'b1) ? (P0+M0) : M0;
end

// DSP1 part
assign PCIN1 = PCOUT0;
always_ff @(posedge clk) begin
  A1_d <= {{(27-DATA_WIDTH){data_loop1[TAP_NUM_HALF-1][DATA_WIDTH-1]}}, data_loop1[TAP_NUM_HALF-1]};
  B1_d <= {{(18-TAP_WIDTH){tap_loop1[TAP_NUM_HALF-2][TAP_WIDTH-1]}}, tap_loop1[TAP_NUM_HALF-2]};
  A1 <= A1_d;
  B1 <= B1_d;
  M1 <= $signed(A1) * $signed(B1);
  P1 <= (OPMODE_d==2'b00) ? M1 : ( (OPMODE_d==2'b01) ? (P1+PCIN1+M1) : P1+M1);
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
  else if(count_loop_dd == TAP_NUM_HALF) begin
    data_dout_o <= P1[23:8];
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
