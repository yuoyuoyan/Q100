// Author     : Qi Wang
// Date       : 08/23/2020
// Description: Sound player module is used to take the 16-bits 5kHz sound data from RAM
//              and play it in the PWM pattern
module sound_player(
    input clk,
	input rst,
	
(* mark_debug *)	input        sw_play, // switch to play the result (1) or org (0) sound
	input        sw_sd,
	
	// interface to RAM
(* mark_debug *)	output logic [15:0] data_addr,
(* mark_debug *)	input        [15:0] data_org_din,
(* mark_debug *)	input        [15:0] data_filtered_din,
	
	// Port to mono audio output
(* mark_debug *)    output logic AUD_PWM,
(* mark_debug *)    output logic AUD_SD
);

// Create a 512 clock cycle loop
logic [15:0] PWM_count;
always @(posedge clk)
    if(rst) PWM_count <= 16'd0;
    else if(PWM_count < 16'd512) PWM_count <= PWM_count + 16'd1;
    else PWM_count <= 16'd0;

// Based on the switch config, choose the RAM to read and play
always_ff @(posedge clk)
    if(rst) data_addr <= 16'h0;
	else data_addr <= (PWM_count==16'd511) ? data_addr + 1 : data_addr;

logic [15:0] PWM_thresh;
always_ff @(posedge clk)
    PWM_thresh <= sw_play ? data_filtered_din : data_org_din;

// Drive PWM sound wave
always @(posedge clk)
    if(rst) AUD_PWM <= 1'b0;
    else begin
        if(PWM_count<PWM_thresh) AUD_PWM <= 1'b1;
        else AUD_PWM <= 1'b0;
	end

//always_ff @(posedge clk) AUD_SD <= sw_sd;
assign AUD_SD = 1'b1;

endmodule
