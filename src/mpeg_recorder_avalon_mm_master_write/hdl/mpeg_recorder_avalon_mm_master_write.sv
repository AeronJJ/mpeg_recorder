`default_nettype none
module mpeg_recorder_avalon_mm_master_write 
  #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 30
    )(
      input wire                  clk,
      input wire                  rst, // Active high reset

      output reg [ADDR_WIDTH-1:0] address,
      output wire [3:0]           burstcount,
      output reg [DATA_WIDTH-1:0] writedata,
      output wire [3:0]           byteenable,
      output reg                  write,

      input wire                  waitrequest,
      input wire                  en
      );

  assign burstcount = 4'd1;
  assign byteenable = 4'b1111;

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
      writedata  <= '0;
      counter    <= 32'd0;
      write      <= 1'b0;
    end 
    else begin
      case (state)
        IDLE: begin
          if (en) begin
            // prepare next write
            writedata <= 32'h9af0;
//counter;
            write     <= 1'b1;
            // write     <= 1'b0;
            state     <= WRITE;
          end
        end

        WRITE: begin
          if (~waitrequest) begin
            // transfer accepted
            write     <= 1'b0;
            if (address == 32'h3a399999) begin
              address <= 32'h34000000;
              counter <= '0;
            end
            else begin
              address <= address + 1'b1;
            end
            counter   <= counter + 1'b1;
            state     <= IDLE;
          end
          // else: hold address/writedata/write stable
        end
      endcase
    end
  end

endmodule
`default_nettype wire
