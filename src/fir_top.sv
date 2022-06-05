// Author     : Qi Wang
// Date       : 12/05/2020
// Description: This module is designed to be parameterized FIR filter
//              Goal is to have multiple parallel 10-tap one dimensional FIR cores, including riscv, single dsp, dual dsp, single channel and sym channel
//              Controlled by separated swith, they read the recorded original data, and filter them in their own way, and store into result RAM
//              The player will play the original sound or filtered sound based on switch control
//              LEDs are used to check whether related core has finished the job
module fir_top (
    input clk,
    input rst,

	input        sw_record, // assert to record sound
    input        sw_play, // switch to play the result (1) or org (0) sound
	input        sw_riscv, // assert to filter with riscv core
	input        sw_single_dsp, // assert to filter with single_dsp core
	input        sw_dual_dsp, // assert to filter with dual_dsp core
	input        sw_single_chan, // assert to filter with single_chan core
	input        sw_sym_chan, // assert to filter with sym_chan core
	input        sw_sd,
	// LEDs to indicate that cores have finished the FIR operation
	output logic led_riscv_done,
	output logic led_single_dsp_done,
	output logic led_dual_dsp_done,
	output logic led_single_chan_done,
	output logic led_sym_chan_done,
    
    // Port to microphone
    output logic MIC_CLK,
    input        MIC_DATA,
    output logic MIC_LR_SEL,
    
    // Port to mono audio output
    output logic AUD_PWM,
    output logic AUD_SD
);

// convert the 100M system clock into 50M, since riscv core cannot reach it
/*
logic clk_50M;
logic locked;
clk_100M_50M u_clk
(
    .clk_out1(clk_50M),     // output clk_out1
    .reset(rst), // input reset
    .locked(locked),       // output locked
    .clk_in1(clk)
);
*/
// used for simulation only
assign clk_50M = clk;
assign locked = !rst;

// signal definition
logic [15:0] data_recorder_addr;
logic [15:0] data_recorder_ram;
logic        data_recorder_we;

logic [15:0] data_player_addr;
logic [15:0] data_org_ram_player;
logic [15:0] data_filtered_ram_player;

logic [15:0] data_addr_org_ram;
logic [15:0] data_addr_filtered_ram;
logic        data_we_filtered_ram;
logic [15:0] data_din_filtered_ram;

logic [16:0] data_riscv_addr;
logic [3:0]  data_riscv_we;
logic [31:0] data_riscv_ram;
logic [31:0] data_ram_riscv;
logic        riscv_done_intr;
logic        riscv_rst;

logic [15:0] data_single_dsp_addr_rd;
logic [15:0] data_single_dsp_addr_wr;
logic        data_single_dsp_we;
logic [15:0] data_single_dsp_ram;
logic [15:0] data_ram_single_dsp;
logic        single_dsp_done_intr;
logic        single_dsp_rst;

logic [15:0] data_dual_dsp_addr_rd;
logic [15:0] data_dual_dsp_addr_wr;
logic        data_dual_dsp_we;
logic [15:0] data_dual_dsp_ram;
logic [15:0] data_ram_dual_dsp;
logic        dual_dsp_done_intr;
logic        dual_dsp_rst;

logic [15:0] data_single_chan_addr_rd;
logic [15:0] data_single_chan_addr_wr;
logic        data_single_chan_we;
logic [15:0] data_single_chan_ram;
logic [15:0] data_ram_single_chan;
logic        single_chan_done_intr;
logic        single_chan_rst;

logic [15:0] data_sym_chan_addr_rd;
logic [15:0] data_sym_chan_addr_wr;
logic        data_sym_chan_we;
logic [15:0] data_sym_chan_ram;
logic [15:0] data_ram_sym_chan;
logic        sym_chan_done_intr;
logic        sym_chan_rst;

// sound recorder
sound_recorder u_recorder(
    .clk (clk_50M),
	.rst (!locked),
	.sw_record, // press down to record sound
	// Port to microphone
	.MIC_CLK,
	.MIC_DATA,
	.MIC_LR_SEL,
	// interface to RAM
	.data_addr (data_recorder_addr),
	.data_dout (data_recorder_ram),
	.data_we   (data_recorder_we)
);

// riscv core
q100_core #(
    .EXT_DTCM(1),
	.EXT_ITCM(0)
) u_riscv_core
(
    .clk (clk_50M),
	.rst (riscv_rst),
	// Interface to the external ITCM and DTCM if used
    .itcm_addr_o(),
    .itcm_we_o  (),
    .itcm_dout_o(),
    .itcm_din_i (),
	
    .dtcm_addr_o(data_riscv_addr),
    .dtcm_we_o  (data_riscv_we),
    .dtcm_dout_o(data_riscv_ram),
    .dtcm_din_i (data_ram_riscv),
	// done interrupt
	.done_intr_o(riscv_done_intr)
);
// only release the riscv when the switch is asserted
always_ff @(posedge clk_50M) begin
    led_riscv_done <= riscv_done_intr;
    if(!locked) riscv_rst <= 1'b1;
	else if(sw_riscv) riscv_rst <= 1'b0;
	else riscv_rst <= 1'b1;
end

// single-DSP core
fir_single_dsp u_single_dsp_core(
  .clk (clk_50M),
  .rst (single_dsp_rst),

  .data_addr_rd_o (data_single_dsp_addr_rd),
  .data_addr_wr_o (data_single_dsp_addr_wr),
  .data_din_i     (data_ram_single_dsp),
  .data_dout_o    (data_single_dsp_ram),
  .data_we_o      (data_single_dsp_we),
  
  .done_intr (single_dsp_done_intr)
);
always_ff @(posedge clk_50M) begin
    led_single_dsp_done <= single_dsp_done_intr;
    if(!locked) single_dsp_rst <= 1'b1;
	else if(sw_single_dsp) single_dsp_rst <= 1'b0;
	else single_dsp_rst <= 1'b1;
end

// dual-DSP core
fir_double_dsp u_dual_dsp_core(
  .clk (clk_50M),
  .rst (dual_dsp_rst),
  
  .data_addr_rd_o (data_dual_dsp_addr_rd),
  .data_addr_wr_o (data_dual_dsp_addr_wr),
  .data_din_i     (data_ram_dual_dsp),
  .data_dout_o    (data_dual_dsp_ram),
  .data_we_o      (data_dual_dsp_we),
  
  .done_intr (dual_dsp_done_intr)
);
always_ff @(posedge clk_50M) begin
    led_dual_dsp_done <= dual_dsp_done_intr;
    if(!locked) dual_dsp_rst <= 1'b1;
	else if(sw_dual_dsp) dual_dsp_rst <= 1'b0;
	else dual_dsp_rst <= 1'b1;
end

// single-chan core
fir_single_chan u_single_chan(
  .clk (clk_50M),
  .rst (single_chan_rst),
  
  .data_addr_rd_o (data_single_chan_addr_rd),
  .data_addr_wr_o (data_single_chan_addr_wr),
  .data_din_i     (data_ram_single_chan),
  .data_dout_o    (data_single_chan_ram),
  .data_we_o      (data_single_chan_we),
  
  .done_intr  (single_chan_done_intr)
);
always_ff @(posedge clk_50M) begin
    led_single_chan_done <= single_chan_done_intr;
    if(!locked) single_chan_rst <= 1'b1;
	else if(sw_single_chan) single_chan_rst <= 1'b0;
	else single_chan_rst <= 1'b1;
end

// sym-chan core
fir_sym_chan u_sym_chan(
  .clk (clk_50M),
  .rst (sym_chan_rst),
  
  .data_addr_rd_o (data_sym_chan_addr_rd),
  .data_addr_wr_o (data_sym_chan_addr_wr),
  .data_din_i     (data_ram_sym_chan),
  .data_dout_o    (data_sym_chan_ram),
  .data_we_o      (data_sym_chan_we),
  
  .done_intr (sym_chan_done_intr)
);
always_ff @(posedge clk_50M) begin
    led_sym_chan_done <= sym_chan_done_intr;
    if(!locked) sym_chan_rst <= 1'b1;
	else if(sw_sym_chan) sym_chan_rst <= 1'b0;
	else sym_chan_rst <= 1'b1;
end

// RAM to store the recorded sound data
// depth is 65536, around 1 seconds
sound_data_ram u_sound_data_ram (
    .clka(clk_50M),    // input wire clka
    .wea(data_recorder_we),      // input wire [0 : 0] wea
    .addra(data_recorder_addr),  // input wire [15 : 0] addra
    .dina(data_recorder_ram),    // input wire [15 : 0] dina
    .clkb(clk_50M),    // input wire clkb
    .enb(1'b1),      // input wire enb
    .addrb(data_addr_org_ram),  // input wire [15 : 0] addrb
    .doutb(data_org_ram_player)  // output wire [15 : 0] doutb
);
always_comb begin
    data_addr_org_ram = sw_riscv ? data_riscv_addr[15:0] :
	                    sw_single_dsp ? data_single_dsp_addr_rd :
						sw_dual_dsp ? data_dual_dsp_addr_rd :
						sw_single_chan ? data_single_chan_addr_rd :
						sw_sym_chan ? data_sym_chan_addr_rd :
						data_player_addr;
end
assign data_ram_riscv = {{16{data_org_ram_player[15]}}, data_org_ram_player};
assign data_ram_single_dsp = data_org_ram_player;
assign data_ram_dual_dsp = data_org_ram_player;
assign data_ram_single_chan = data_org_ram_player;
assign data_ram_sym_chan = data_org_ram_player;

// RAM to store the filtered sound data
// depth is 65536
sound_data_ram u_result_data_ram (
    .clka(clk_50M),    // input wire clka
    .wea(data_we_filtered_ram),      // input wire [0 : 0] wea
    .addra(data_addr_filtered_ram),  // input wire [15 : 0] addra
    .dina(data_din_filtered_ram),    // input wire [15 : 0] dina
    .clkb(clk_50M),    // input wire clkb
    .enb(1'b1),      // input wire enb
    .addrb(data_player_addr),  // input wire [15 : 0] addrb
    .doutb(data_filtered_ram_player)  // output wire [15 : 0] doutb
);
always_comb begin
    data_we_filtered_ram = sw_riscv ? data_riscv_we[0] :
	                       sw_single_dsp ? data_single_dsp_we :
						   sw_dual_dsp ? data_dual_dsp_we :
						   sw_single_chan ? data_single_chan_we :
						   sw_sym_chan ? data_sym_chan_we :
						   1'b0;
	data_addr_filtered_ram = sw_riscv ? data_riscv_addr[15:0] :
	                         sw_single_dsp ? data_single_dsp_addr_wr :
						     sw_dual_dsp ? data_dual_dsp_addr_wr :
						     sw_single_chan ? data_single_chan_addr_wr :
						     sw_sym_chan ? data_sym_chan_addr_wr :
						     0;
	data_din_filtered_ram = sw_riscv ? data_riscv_ram[15:0] :
	                        sw_single_dsp ? data_single_dsp_ram :
						    sw_dual_dsp ? data_dual_dsp_ram :
						    sw_single_chan ? data_single_chan_ram :
						    sw_sym_chan ? data_sym_chan_ram :
						    0;
end

// sound player
sound_player u_player(
    .clk (clk_50M),
	.rst (!locked),
	.sw_play, // switch to play the result (1) or org (0) sound
	.sw_sd,
	// interface to RAM
	.data_addr          (data_player_addr),
	.data_org_din       (data_org_ram_player),
	.data_filtered_din  (data_filtered_ram_player),
	//.data_din  (data_recorder_ram),
	// Port to mono audio output
    .AUD_PWM,
    .AUD_SD
);

endmodule
