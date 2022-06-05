// Author     : Qi Wang
// Date       : 08/23/2020
// Description: Sound recorder module is used to take the PDM sound data input (1 bit),
//              and transform it into 16-bits 5kHz data
//              send the data out in the RAM interface (16x8192)
module sound_recorder(
    input clk,
	input rst,
	
(* mark_debug *)	input        sw_record, // press down to record sound
	
	// Port to microphone
(* mark_debug *)	output logic MIC_CLK,
(* mark_debug *)	input        MIC_DATA,
(* mark_debug *)	output logic MIC_LR_SEL,
	
	// interface to RAM
(* mark_debug *)	output logic [15:0] data_addr,
(* mark_debug *)	output logic [15:0] data_dout,
(* mark_debug *)	output logic        data_we
);

// Generate 2.5MHz to MIC_CLK, and rising edge detection
logic [7:0] MIC_CLK_count;
logic       MIC_CLK_d;
logic       MIC_CLK_posedge;
always_ff @(posedge clk) begin
    if(rst) begin
        MIC_CLK <= 1'b0;
        MIC_CLK_count <= 8'd0;
    end
    else if(MIC_CLK_count < 8'd19) begin
        MIC_CLK_count <= MIC_CLK_count + 8'd1;
    end
    else begin
        MIC_CLK <= ~MIC_CLK;
        MIC_CLK_count <= 8'd0;
    end
end

always_ff @(posedge clk) MIC_CLK_d <= MIC_CLK;
assign MIC_CLK_posedge = ({MIC_CLK_d, MIC_CLK}==2'b01) ? 1'b1 : 1'b0;

// detect the record button, only record an entire RAM after the button is pressed
(* mark_debug *)logic record_run;
logic [16:0]  data_addr_r;
always_ff @(posedge clk)
    if(rst) record_run <= 1'b0;
	else if(record_run && data_addr_r==17'h10000) record_run <= 1'b0;
	else if(sw_record) record_run <= 1'b1;

// PDM counter increase every rising edge of MIC_CLK
// period is 128
genvar i;
reg [7:0] PDM_counter;
always @(posedge clk or posedge rst) begin
    if(rst) begin
        PDM_counter <= 8'd0;
    end
    else if(MIC_CLK_posedge & record_run) begin
        PDM_counter <= (PDM_counter == 8'd127) ? 8'd0 : PDM_counter + 8'd1;
    end
end

// ten counters control, start by floor(12.8*i)
localparam [8*10-1:0] PDM_thresh_counter_start = 
{8'd115, 8'd102, 8'd89, 8'd76, 8'd64, 
8'd51, 8'd38, 8'd25, 8'd12, 8'd0};

logic [9:0][7:0] PDM_thresh_counter;
generate
    for(i=0; i<10; i=i+1) begin : PDM_COUNTERS
        always_ff @(posedge clk or posedge rst) begin
            if(rst) begin
                PDM_thresh_counter[i] <= 8'd0;
            end
            else if(MIC_CLK_posedge && (PDM_counter == PDM_thresh_counter_start[8*i+7:8*i])) begin
                PDM_thresh_counter[i] <= (MIC_DATA) ? 8'd1 : 8'd0;
            end
            else if(MIC_CLK_posedge) begin
                PDM_thresh_counter[i] <= (MIC_DATA) ? PDM_thresh_counter[i] + 8'd1 : PDM_thresh_counter[i];
            end
        end
    end
endgenerate

logic [15:0] PDM_count;
logic [15:0] led_threshold;
always_ff @(posedge clk) begin
    if(rst) begin
        PDM_count <= 16'd0;
        data_dout <= 16'h0;
		data_addr_r <= 17'h0;
		data_we <= 1'b0;
    end
    else if(record_run) begin
        PDM_count <= (PDM_count == 16'd5119) ? 16'd0 : PDM_count + 16'd1;
        case(PDM_count)
        16'd0    : begin 
		    data_addr_r <= data_addr_r + 1; 
			data_we <= 1'b1; 
			data_dout <= {6'h0, PDM_thresh_counter[0], 2'b00}; 
		end
        16'd480  : begin 
		    data_addr_r <= data_addr_r + 1; 
			data_we <= 1'b1; 
			data_dout <= {6'h0, PDM_thresh_counter[1], 2'b00}; 
		end
        16'd1000 : begin 
		    data_addr_r <= data_addr_r + 1; 
			data_we <= 1'b1; 
			data_dout <= {6'h0, PDM_thresh_counter[2], 2'b00}; 
		end
        16'd1520 : begin 
		    data_addr_r <= data_addr_r + 1; 
			data_we <= 1'b1; 
			data_dout <= {6'h0, PDM_thresh_counter[3], 2'b00}; 
		end
        16'd2040 : begin 
		    data_addr_r <= data_addr_r + 1; 
			data_we <= 1'b1; 
			data_dout <= {6'h0, PDM_thresh_counter[4], 2'b00}; 
		end
        16'd2560 : begin 
		    data_addr_r <= data_addr_r + 1; 
			data_we <= 1'b1; 
			data_dout <= {6'h0, PDM_thresh_counter[5], 2'b00}; 
		end
        16'd3040 : begin 
		    data_addr_r <= data_addr_r + 1; 
			data_we <= 1'b1; 
			data_dout <= {6'h0, PDM_thresh_counter[6], 2'b00}; 
		end
        16'd3560 : begin 
		    data_addr_r <= data_addr_r + 1; 
			data_we <= 1'b1; 
			data_dout <= {6'h0, PDM_thresh_counter[7], 2'b00}; 
		end
        16'd4080 : begin 
		    data_addr_r <= data_addr_r + 1; 
			data_we <= 1'b1; 
			data_dout <= {6'h0, PDM_thresh_counter[8], 2'b00}; 
		end
        16'd4600 : begin 
		    data_addr_r <= data_addr_r + 1; 
			data_we <= 1'b1; 
			data_dout <= {6'h0, PDM_thresh_counter[9], 2'b00}; 
		end
		default  : begin data_we <= 1'b0; end
        endcase
    end
	else begin
	    PDM_count <= 16'd0;
	    data_addr_r <= 0;
		data_we <= 0;
	end
end

assign data_addr = data_addr_r[15:0];
assign MIC_LR_SEL = 1'b0;

endmodule