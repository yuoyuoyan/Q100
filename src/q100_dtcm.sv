// DTCM module, basically just a RAM
// but separated to banks for every 8 bits (1 byte)
// Need to make sure DTCM_DATA_WIDTH = 8*DTCM_BANK
module q100_dtcm #(
    parameter DTCM_DATA_WIDTH = 32,
	parameter DTCM_ADDR_WIDTH = 12,
	parameter DTCM_BANK = 4,
	parameter INIT_FILE = ""  // Specify name/location of RAM initialization file if using one (leave blank if not)
)
(
    input clk,
	input rst,
	input         [DTCM_ADDR_WIDTH-1:0] dtcm_addr_i,
	input         [DTCM_BANK-1:0]       dtcm_we_i,
	output        [DTCM_DATA_WIDTH-1:0] dtcm_data_o,
	input         [DTCM_DATA_WIDTH-1:0] dtcm_data_i
);

dtcm_ram_sdp u_ram_sdp (
  .clka(clk),    // input wire clka
  .wea(wea),      // input wire [3 : 0] wea
  .addra(dtcm_addr_i[11:2]),  // input wire [9 : 0] addra
  .dina(dtcm_data_i),    // input wire [35 : 0] dina
  .douta(dtcm_data_o)  // output wire [35 : 0] douta
);
/*
  parameter RAM_WIDTH = DTCM_DATA_WIDTH/DTCM_BANK;
  parameter RAM_DEPTH = 2**DTCM_ADDR_WIDTH/DTCM_BANK;                  // Specify RAM depth (number of entries)

  (* ram_style = "block" *)
  reg [RAM_WIDTH-1:0] dtcm_ram [DTCM_BANK-1:0][RAM_DEPTH-1:0];
  reg [DTCM_DATA_WIDTH-1:0] dtcm_ram_data = {RAM_WIDTH{1'b0}};

  // The following code either initializes the memory values to a specified file or to all zeros to match hardware
  integer bank_index;
  generate
    if (INIT_FILE != "") begin: use_init_file
      initial
	    for (bank_index = 0; bank_index < DTCM_BANK; bank_index = bank_index + 1)
          $readmemh(INIT_FILE, dtcm_ram[bank_index], 0, RAM_DEPTH-1);
    end else begin: init_bram_to_zero
      integer ram_index;
      initial
	    for (bank_index = 0; bank_index < DTCM_BANK; bank_index = bank_index + 1)
          for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
            dtcm_ram[bank_index][ram_index] = {RAM_WIDTH{1'b0}};
    end
  endgenerate

  generate
    for (genvar i = 0; i < DTCM_BANK; i = i + 1)
      always @(posedge clk) begin
        if (dtcm_we_i[i])
          dtcm_ram[i][dtcm_addr_i[DTCM_ADDR_WIDTH-1:2]] <= dtcm_data_i[RAM_WIDTH*(i+1)-1 : RAM_WIDTH*i];
      end
  endgenerate
  
  always @(posedge clk)
    dtcm_ram_data <= {
	  dtcm_ram[3][dtcm_addr_i[DTCM_ADDR_WIDTH-1:2]], 
	  dtcm_ram[2][dtcm_addr_i[DTCM_ADDR_WIDTH-1:2]], 
	  dtcm_ram[1][dtcm_addr_i[DTCM_ADDR_WIDTH-1:2]], 
	  dtcm_ram[0][dtcm_addr_i[DTCM_ADDR_WIDTH-1:2]]};

  // The following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing
  assign dtcm_data_o = dtcm_ram_data;
*/
endmodule
