`default_nettype none
module mpeg_playback_avalon_mm_master_read 
  #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter NUM_BYTES = DATA_WIDTH / 8,
    parameter BUF0_BASE_ADDR = 32'h32000000,
    parameter BUF1_BASE_ADDR = 32'h38400000,
    parameter BUFFER_LENGTH = 32'h06400000,
    parameter BUFFER_OFFSET = 32'd36 // offset to account for non-perfect buffer size
    )
  (
   /* verilator lint_off UNUSEDSIGNAL */
   input wire                     clk,
   input wire                     rst,         // Active high

   output reg [ADDR_WIDTH - 1:0]  address,
   output wire [NUM_BYTES - 1:0]  burstcount,
   input wire [DATA_WIDTH - 1:0]  readdata,
   output wire [NUM_BYTES - 1:0]  byteenable,
   output reg                     read,
   input wire                     waitrequest,
   input wire                     readdatavalid,

   input wire                     en,
   input wire                     packet_done, // Send new packet when pulsed,
   output wire                    new_clk,
   output wire [DATA_WIDTH - 1:0] w_data,
   output reg [5:0]               w_addr,
   output wire                    w_en_pb0,
   output wire                    w_en_pb1,

   input wire                     buffer0_filled,
   input wire                     buffer1_filled,

   output wire                    buffer0_fill_request_irq,
   output wire                    buffer1_fill_request_irq,
   input wire                     buffer0_fill_request_irq_received,
   input wire                     buffer1_fill_request_irq_received,

   output reg                     init_done,   // Goes high once pb0 is filled
   output reg [31:0]              mpeg_sync_clk_cycle_count // This is in sys clock domain, so has potential to glitch...
   );

  localparam [31:0] BUF0_LAST_WORD_ADDR =
                    BUF0_BASE_ADDR + BUFFER_LENGTH - 32'd4;

  localparam [31:0] BUF1_LAST_WORD_ADDR =
                    BUF1_BASE_ADDR + BUFFER_LENGTH - 32'd4;
  
  wire              reading_clk_cycle_word =
                    (address == BUF0_LAST_WORD_ADDR) ||
                    (address == BUF1_LAST_WORD_ADDR);

  // Synchronise packet done in //
  reg packet_done_d;
  reg packet_done_sync;
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      packet_done_d <= 1'b0;
      packet_done_sync <= 1'b0;
    end
    else begin
      packet_done_d <= packet_done;
      packet_done_sync <= packet_done_d;
    end
  end  
  // //

  assign new_clk = clk;

  // Instantiate IRQs //
  reg en_buffer0_fill_request_irq;
  mpeg_irq mpeg_irq_buffer0_irq_inst
    (
     .clk(clk),
     .rst_n(~rst),
     .en_interrupt(en_buffer0_fill_request_irq),
     .irq(buffer0_fill_request_irq),
     .irq_reset(buffer0_fill_request_irq_received)
     );

  reg en_buffer1_fill_request_irq;
  mpeg_irq mpeg_irq_buffer1_irq_inst
    (
     .clk(clk),
     .rst_n(~rst),
     .en_interrupt(en_buffer1_fill_request_irq),
     .irq(buffer1_fill_request_irq),
     .irq_reset(buffer1_fill_request_irq_received)
     );
  // //

  reg [ADDR_WIDTH - 1:0] readdata_reg;
  reg                    writeready;
  reg                    read_accepted;
  assign burstcount = 4'd1;
  assign byteenable = 4'b1111;
  assign w_data = readdata_reg;
                  // { readdata_reg[7:0],
                  //   readdata_reg[15:8],
                  //   readdata_reg[23:16],
                  //   readdata_reg[31:24]                   
                  //   };

  // Control read signal and register read data //
  reg read_ready;
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      read <= 1'b0;
      read_accepted <= 1'b0;
      readdata_reg <= '0;
      writeready <= 1'b0;
      mpeg_sync_clk_cycle_count <= 32'd0;
    end
    else if (~waitrequest && read) begin // Read accepted
      read <= 1'b0;
      read_accepted <= 1'b1;
    end
    else if (read_accepted && readdatavalid) begin 
      if (reading_clk_cycle_word) begin
        mpeg_sync_clk_cycle_count <= { readdata[7:0],
                                       readdata[15:8],
                                       readdata[23:16],
                                       readdata[31:24]                   
                                       };
        writeready <= 1'b0;
      end
      else begin
        readdata_reg <= readdata;
        writeready <= 1'b1;
      end
      
      read_accepted <= 1'b0;
    end
    else if (read_ready) begin
      read <= 1'b1;
      writeready <= 1'b0;
    end
    else if (current_state == s_WRITE) begin
      writeready <= 1'b0;
    end
  end // always_ff @ (posedge clk or posedge rst)
  // //

  // Control packet buffer write interface //
  reg fill_pb0; // Used to init pb0
  reg pb_sel;
  reg w_en;
  assign w_en_pb0 = writeready & ~pb_sel;
  assign w_en_pb1 = writeready & pb_sel;
  // // 

  // State Machine //
  localparam s_IDLE = 4'd0;
  localparam s_INIT = 4'd1;      // Requests fill buffer 0, 
  localparam s_INIT_WAIT = 4'd2; // waits for finish
  localparam s_REQ_BUF1 = 4'd3;  // Request buffer 1 fill
  localparam s_REQ_BUF0 = 4'd4;  // Request buffer 0 fill
  localparam s_WAIT = 4'd5;      // Wait for packet buffer fill request
  localparam s_READ = 4'd6;      // Read from active buffer
  localparam s_WAIT_READ = 4'd7; // Wait for read to process
  localparam s_WRITE = 4'd8;     // Write into packet buffer
  localparam s_DONE = 4'd9;      // Packet buffer filled
  localparam s_STOP = 4'd10;     // Stops process and goes to idle

  reg [3:0]  current_state;
  reg [3:0]  next_state;

  // int        delay;
  
  always_ff @ (posedge clk or posedge rst) begin
    if (rst) begin
      current_state <= s_IDLE;
      init_done <= 1'b0;
      fill_pb0 <= 1'b0;
      
      en_buffer0_fill_request_irq <= 1'b0;
      en_buffer1_fill_request_irq <= 1'b0;
      
      address <= BUF0_BASE_ADDR;
      read_ready <= 1'b0;

      pb_sel <= 1'b0;
      w_en <= 1'b0;
      w_addr <= 6'd0;

      // delay <= '0;
    end // if (rst)
    // else if (delay > '0) begin
    //   delay <= delay - 1'b1;
    // end
    else if (en) begin
      current_state <= next_state;
      case (current_state)
        s_IDLE: begin
          // delay <= 32'd5000000;          
        end

        s_INIT: begin
          en_buffer0_fill_request_irq <= 1'b1;
          fill_pb0 <= 1'b1; // Initialise packet buffer 0
          pb_sel <= 1'b0; // Select packet buffer 0 for writing
          init_done <= 1'b0; // Stop from playing back until packet buffer 0 filled
        end

        s_INIT_WAIT: begin
          en_buffer0_fill_request_irq <= 1'b0;
          // delay <= 32'd50000000 * 10; // 10 second wait
        end

        s_REQ_BUF1: begin
          en_buffer1_fill_request_irq <= 1'b1;
          address <= BUF0_BASE_ADDR;
        end

        s_REQ_BUF0: begin
          en_buffer0_fill_request_irq <= 1'b1;
          address <= BUF1_BASE_ADDR;
        end

        s_WAIT: begin
          en_buffer0_fill_request_irq <= 1'b0;
          en_buffer1_fill_request_irq <= 1'b0;
          w_addr <= 6'd0;
        end          

        s_READ: begin
          fill_pb0 <= 1'b0;
          read_ready <= 1'b1;
          w_en <= 1'b0;
          if (address >= BUF0_BASE_ADDR + BUFFER_LENGTH - BUFFER_OFFSET && address < BUF1_BASE_ADDR) begin 
            address <= BUF0_LAST_WORD_ADDR;
          end
          else if (address >= BUF1_BASE_ADDR + BUFFER_LENGTH - BUFFER_OFFSET) begin
            address <= BUF1_LAST_WORD_ADDR;
          end
        end
        
        s_WAIT_READ: begin
          read_ready <= 1'b0;
        end

        s_WRITE: begin
          w_en <= 1'b1;
          // Increment addresses
          address <= address + 32'd4;
          w_addr <= w_addr + 6'd1;
        end

        s_DONE: begin
          w_en <= 1'b0;
          pb_sel <= ~pb_sel; // Flip pb selection
          init_done <= 1'b1; // Indicate that packet buffers can be read
        end

        s_STOP: begin
          
        end

        default: begin

        end
      endcase
    end
    else begin
      current_state <= s_IDLE;
    end
  end // always_ff @ (posedge clk or posedge rst)

  always_comb begin
    next_state = current_state;
    case (current_state)
      s_IDLE: begin
        if (en) begin
          next_state = s_INIT;
        end
      end

      s_INIT: begin
        next_state = s_INIT_WAIT;
      end

      s_INIT_WAIT: begin
        if (buffer0_filled) begin
          next_state = s_REQ_BUF1;
        end
      end

      s_REQ_BUF1: begin
        next_state = s_WAIT;
      end

      s_REQ_BUF0: begin
        next_state = s_WAIT;        
      end

      s_WAIT: begin
        if (packet_done_sync || fill_pb0) begin
          next_state = s_READ;
        end
      end          

      s_READ: begin
        next_state = s_WAIT_READ;
      end

      s_WAIT_READ: begin
        if (writeready) begin
          next_state = s_WRITE;
        end
        else if ((readdatavalid == 1'b1) && (reading_clk_cycle_word)) begin
          next_state = s_DONE;
        end
      end

      s_WRITE: begin
        if (w_addr < 6'd46) begin
          next_state = s_READ;
        end
        else begin
          next_state = s_DONE;
        end
      end

      s_DONE: begin
        if (address == BUF0_LAST_WORD_ADDR) begin
          // Buffer 0 empty, req buf0
          next_state = s_REQ_BUF0;
        end
        else if (address == BUF1_LAST_WORD_ADDR) begin
          // Buffer 1 empty, req buf1
          next_state = s_REQ_BUF1;
        end
        else if (address >= BUF0_BASE_ADDR + BUFFER_LENGTH - BUFFER_OFFSET && address < BUF1_BASE_ADDR) begin 
          // Buffer 0 empty, read clock cycle count
          next_state = s_READ;
        end
        else if (address >= BUF1_BASE_ADDR + BUFFER_LENGTH - BUFFER_OFFSET) begin
          // Buffer 1 empty, read clock cycle count
          next_state = s_READ;
        end
        else begin
          next_state = s_WAIT;
        end
      end // case: s_DONE

      s_STOP: begin
        next_state = s_IDLE;
      end  

      default: begin
        next_state = s_IDLE;
      end          
    endcase
  end
  
  // // 

endmodule // mpeg_playback_avalon_mm_master_read
`default_nettype wire
  
