`timescale 1ns/1ns
`include "q100_config.svh"
module tb_q100;

`define ITCM           tb_q100.q100.u_itcm.itcm_ram
`define DTCM           tb_q100.q100.u_dtcm.dtcm_ram
`define PC             tb_q100.q100.u_exu.u_fetch.pc

logic clk;
logic rst;
logic sw_record; // assert to record sound
logic sw_play; // switch to play the result (1) or org (0) sound
logic sw_riscv; // assert to filter with riscv core
logic sw_single_dsp; // assert to filter with single_dsp core
logic sw_dual_dsp; // assert to filter with dual_dsp core
logic sw_single_chan; // assert to filter with single_chan core
logic sw_sym_chan; // assert to filter with sym_chan core
logic sw_sd;
logic led_riscv_done;
logic led_single_dsp_done;
logic led_dual_dsp_done;
logic led_single_chan_done;
logic led_sym_chan_done;
logic MIC_CLK;
logic MIC_DATA;
logic MIC_LR_SEL;
logic AUD_PWM;
logic AUD_SD;

initial begin
    clk = 1'b0;
    rst = 1'b0;

	sw_record = 0;
	sw_play = 0;
	sw_riscv = 0;
	sw_single_dsp = 0;
	sw_dual_dsp = 0;
	sw_single_chan = 0;
	sw_sym_chan = 0;
	sw_sd = 1;
    // Reset for 1us
    #100  rst = 1'b1;
    #1000 rst = 1'b0;
	// Record some sound data
	#1000 sw_record = 1;
	#100000 sw_record = 0;
	#1000 sw_riscv = 1;
	wait(led_single_dsp_done==1) sw_riscv = 0;
	//#1000 sw_single_dsp = 1;
	//wait(led_single_dsp_done==1) sw_single_dsp = 0;
	//#1000 sw_dual_dsp = 1;
	//wait(led_dual_dsp_done==1) sw_dual_dsp = 0;
	//#1000 sw_single_chan = 1;
	//wait(led_single_chan_done==1) sw_single_chan = 0;
	//#1000 sw_sym_chan = 1;
	//wait(led_sym_chan_done==1) sw_sym_chan = 0;
end

always #10 MIC_DATA = $random%2;

// Generate 100MHz clock signal
always #5 clk <= ~clk;
fir_top fir(
    .clk,
    .rst,
	.sw_record, // assert to record sound
    .sw_play, // switch to play the result (1) or org (0) sound
	.sw_riscv, // assert to filter with riscv core
	.sw_single_dsp, // assert to filter with single_dsp core
	.sw_dual_dsp, // assert to filter with dual_dsp core
	.sw_single_chan, // assert to filter with single_chan core
	.sw_sym_chan, // assert to filter with sym_chan core
	.sw_sd,
	// LEDs to indicate that cores have finished the FIR operation
	.led_riscv_done,
	.led_single_dsp_done,
	.led_dual_dsp_done,
	.led_single_chan_done,
	.led_sym_chan_done,
    // Port to microphone
    .MIC_CLK,
    .MIC_DATA,
    .MIC_LR_SEL,
    // Port to mono audio output
    .AUD_PWM,
    .AUD_SD
);

endmodule
