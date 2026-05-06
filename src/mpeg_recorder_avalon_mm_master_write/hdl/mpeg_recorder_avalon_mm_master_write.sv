`default_nettype none
module mpeg_recorder_avalon_mm_master_write 
  #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter NUM_BYTES = DATA_WIDTH / 8,
    parameter BUF0_BASE_ADDR = 32'h32000000,
    parameter BUF1_BASE_ADDR = 32'h38400000,
    parameter BUFFER_LENGTH = 32'h06400000
    )
  (
   input wire                     clk,
   input wire                     rst, // Active high reset

   output reg [ADDR_WIDTH - 1:0]  address,
   output wire [NUM_BYTES - 1:0]  burstcount,
   output wire [DATA_WIDTH - 1:0] writedata,
   output wire [NUM_BYTES - 1:0]  byteenable,
   output reg                     write,
   input wire                     waitrequest,

   input wire                     en,
   input wire                     packet_done,
   input wire [DATA_WIDTH - 1:0]  r_data,
   output wire [5:0]              r_addr,
   output reg                     r_en,

   output wire                    buffer0_done_irq,
   output wire                    buffer1_done_irq,
   input wire                     buffer0_done_irq_received,
   input wire                     buffer1_done_irq_received
   );
  // TODO: Update with response signal from avalon interface

  // Instantiate IRQs //
  reg en_buffer0_done_irq;
  mpeg_irq mpeg_irq_buffer0_irq_inst
    (
     .clk(clk),
     .rst_n(~rst),
     .en_interrupt(en_buffer0_done_irq),
     .irq(buffer0_done_irq),
     .irq_reset(buffer0_done_irq_received)
     );

  reg en_buffer1_done_irq;
  mpeg_irq mpeg_irq_buffer1_irq_inst
    (
     .clk(clk),
     .rst_n(~rst),
     .en_interrupt(en_buffer1_done_irq),
     .irq(buffer1_done_irq),
     .irq_reset(buffer1_done_irq_received)
     );
  // //
  
  assign burstcount = 4'd1;
  assign byteenable = 4'b1111;
  assign writedata = r_data;
                     // { r_data[7:0], 
                     //   r_data[15:8], 
                     //   r_data[23:16], 
                     //   r_data[31:24] 
                     //   };  

  // Control write signal //
  reg writeready;
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      write <= 1'b0;
    end
    else if (~waitrequest && write) begin
      write <= 1'b0;
    end
    else if (writeready) begin
      write <= 1'b1;
    end
  end // always @ (posedge clk or posedge rst)
  // //

  // Synchronise packet_done into clk domain // Update: sync is now done in mpeg_recorder module
  wire packet_done_sync = packet_done;
  // //

  // State Machine //
  reg [5:0] r_addr_r;
  assign r_addr = r_addr_r;
  
  typedef enum
    {
     s_IDLE,
     s_READ,
     s_WRITE,
     s_WAIT,
     s_DONE
     } state_t;

  state_t current_state;
  state_t next_state;
  
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      r_en <= 1'b0;
      r_addr_r <= '0;
      address <= BUF0_BASE_ADDR;
      writeready <= 1'b0;
      en_buffer0_done_irq <= 1'b0;
      en_buffer1_done_irq <= 1'b0;
      current_state <= s_IDLE;
    end
    else if (en) begin
      current_state <= next_state;
      case (current_state)
        s_IDLE: begin
          r_en <= 1'b0;
          r_addr_r <= '0;
          writeready <= 1'b0;
          en_buffer0_done_irq <= 1'b0;
          en_buffer1_done_irq <= 1'b0;
        end
        
        s_READ: begin
          r_en <= 1'b1;
          writeready <= 1'b0;
        end
        
        s_WRITE: begin
          r_en <= 1'b0;
          writeready <= 1'b1;
        end
        
        s_WAIT: begin
          writeready <= 1'b0;
        end

        s_DONE: begin
          r_addr_r <= r_addr_r + 1'b1;
          if (address == BUF1_BASE_ADDR - 32'h28) begin // Stop just short to ensure alignment of n*47 words
            en_buffer0_done_irq <= 1'b1;
            address <= BUF1_BASE_ADDR;
          end
          else if (address == BUF1_BASE_ADDR + BUFFER_LENGTH - 32'h28) begin
            en_buffer1_done_irq <= 1'b1;
            address <= BUF0_BASE_ADDR;
          end
          else begin
            address <= address + 32'd4; // Increment by 4 bytes
          end
        end

        default: begin

        end
      endcase // case (current_state)
    end // if (en)
    else begin
      r_en <= 1'b0;
      r_addr_r <= '0;
      writeready <= 1'b0;
      address <= BUF0_BASE_ADDR;
      en_buffer0_done_irq <= 1'b0;
      en_buffer1_done_irq <= 1'b0;
      current_state <= s_IDLE;
    end
  end // always_ff @ (posedge clk or posedge rst)

  always_comb begin
    next_state = current_state;
    case (current_state)
      s_IDLE: begin
        if (packet_done_sync) begin
          next_state = s_READ;
        end
      end
      
      s_READ: begin
        next_state = s_WRITE;
      end
      
      s_WRITE: begin
        next_state = s_WAIT;
      end

      s_WAIT: begin
        if (~waitrequest && ~writeready) begin
          next_state = s_DONE;
        end
      end

      s_DONE: begin
        if (r_addr_r == 6'd46) begin
          next_state = s_IDLE;
        end
        else begin
          next_state = s_READ;
        end
      end

      default: begin

      end
    endcase // case (current_state)
  end // always_comb
  // //

endmodule
`default_nettype wire
