// ITCM module, basically just a RAM
module q100_itcm #(
    parameter ITCM_DATA_WIDTH = 32,
	parameter ITCM_ADDR_WIDTH = 12,
	parameter INIT_FILE = ""  // Specify name/location of RAM initialization file if using one (leave blank if not)
)
(
    input clk,
	input rst,
	
	// To itcm
	input         [ITCM_ADDR_WIDTH-1:0] itcm_addr_i,
	input                               itcm_we_i,
	output        [ITCM_DATA_WIDTH-1:0] itcm_data_o,
	input         [ITCM_DATA_WIDTH-1:0] itcm_data_i
);

itcm_ram_sdp u_ram_sdp (
  .clka(clk),    // input wire clka
  .wea(itcm_we_i),      // input wire [0 : 0] wea
  .addra(itcm_addr_i[11:2]),  // input wire [11 : 0] addra
  .dina(itcm_data_i),    // input wire [31 : 0] dina
  .douta(itcm_data_o)  // output wire [31 : 0] douta
);
/*
  parameter RAM_WIDTH = ITCM_DATA_WIDTH;
  parameter RAM_DEPTH = 2**ITCM_ADDR_WIDTH;                  // Specify RAM depth (number of entries)

  (* ram_style = "block" *)
  reg [RAM_WIDTH-1:0] itcm_ram [RAM_DEPTH-1:0];
  reg [RAM_WIDTH-1:0] itcm_ram_data = {RAM_WIDTH{1'b0}};

  // The following code either initializes the memory values to a specified file or to all zeros to match hardware
  generate
    if (INIT_FILE != "") begin: use_init_file
      initial
        $readmemh(INIT_FILE, itcm_ram, 0, RAM_DEPTH-1);
    end else begin: init_bram_to_zero
      integer ram_index;
      initial
        for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
          itcm_ram[ram_index] = {RAM_WIDTH{1'b0}};
    end
  endgenerate

  always @(posedge clk) begin
    if (itcm_we_i)
      itcm_ram[itcm_addr_i[ITCM_ADDR_WIDTH-1:2]] <= itcm_data_i;
  end
  
  always_comb begin
    itcm_ram_data = itcm_ram[itcm_addr_i[ITCM_ADDR_WIDTH-1:2]];
  end

  // The following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing
  assign itcm_data_o = itcm_ram_data;
*/
endmodule
