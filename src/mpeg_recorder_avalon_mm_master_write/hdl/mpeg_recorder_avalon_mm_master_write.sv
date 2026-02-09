`default_nettype none
module mpeg_recorder_avalon_mm_master_write 
  #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 30
    )
  (
   input wire                  clk,
   input wire                  rst, // Active high reset

   output reg [ADDR_WIDTH-1:0] address,
   output wire [3:0]           burstcount,
   output wire [DATA_WIDTH-1:0] writedata,
   output wire [3:0]           byteenable,
   output reg                  write,

   input wire                  waitrequest,
   input wire                  en//,
   // input wire [DATA_WIDTH-1:0] w_data_in,
   // input wire                   
   );

  assign burstcount = 4'd1;
  assign byteenable = 4'b1111;
  reg [DATA_WIDTH-1:0] writedata_internal;
  assign writedata = { writedata_internal[7:0], 
                       writedata_internal[15:8], 
                       writedata_internal[23:16], 
                       writedata_internal[31:24] 
                       };
  
  typedef enum logic 
    {
     IDLE,
     WRITE
     } state_t;

  state_t state;
  reg [31:0] counter;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state      <= IDLE;
      address    <= 32'h34000000;
      writedata_internal <= '0; // 32'h00009af0
      counter    <= 32'd0;
      write      <= 1'b0;
    end 
    else begin
      case (state)
        IDLE: begin
          if (en) begin
            // prepare next write
            writedata_internal <= counter;
            write     <= 1'b1;
            state     <= WRITE;
            if (address == 32'h3a400000) begin
              address <= 32'h34000000;
              counter <= '0;
            end
            else begin
              address <= address + 4;
              counter <= counter + 1'b1;
            end
          end
        end

        WRITE: begin
          if (~waitrequest) begin
            // previous transfer accepted
            write     <= 1'b0;
            state     <= IDLE;
          end
          // else: hold address/writedata/write stable
        end
      endcase
    end
  end

endmodule
`default_nettype wire
