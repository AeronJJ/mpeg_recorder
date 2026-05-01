`timescale 1ns/100ps
module mpeg_playback_tb;

  /* verilator lint_off UNUSEDPARAM */
  /* verilator lint_off UNUSEDSIGNAL */

  localparam CLK_FREQ = 100E6;
  localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;

  localparam MPEG_CLK_FREQ = 6E6;
  localparam MPEG_CLK_HALF_PERIOD_NS = 5E8/MPEG_CLK_FREQ;

  parameter  MPEG_DATA_WIDTH = 8;
  parameter  MPEG_MEM_WIDTH = 4; // Bytes
  parameter  MPEG_MEM_LENGTH = MPEG_DATA_WIDTH * MPEG_MEM_WIDTH;
  parameter  MPEG_ADDR_WIDTH = 6;
  parameter  MPEG_PACKET_LENGTH_BYTES = 188;
  parameter  MPEG_PACKET_LENGTH = MPEG_PACKET_LENGTH_BYTES/MPEG_MEM_WIDTH;  
   
  reg        sys_clk_i;
  reg        rst_n_i;
  reg [MPEG_MEM_LENGTH - 1:0] pb_w_data_i;
  reg [MPEG_ADDR_WIDTH - 1:0] pb_w_addr_i;
  reg                         pb0_w_en_i;
  reg                         pb1_w_en_i;
  reg                         running_i;
  wire                        packet_done_pulse_o;
  reg                         mpeg_clk_6MHz_i;
  reg                         mpeg_sync_i;
  wire                        mpeg_clk_6MHz_out_o;
  wire [MPEG_DATA_WIDTH - 1:0] mpeg_data_8_out_o;
  wire                         mpeg_sync_out_o;
  wire                         mpeg_valid_out_o;
  
  
  mpeg_playback dut_mpeg_playback 
    (
     .sys_clk(sys_clk_i),
     .rst_n(rst_n_i),
     .pb_w_data(pb_w_data_i),
     .pb_w_addr(pb_w_addr_i),
     .pb0_w_en(pb0_w_en_i),
     .pb1_w_en(pb1_w_en_i),
     .running(running_i),
     .packet_done_pulse(packet_done_pulse_o),
     .mpeg_clk_6MHz(mpeg_clk_6MHz_i),
     .mpeg_sync(mpeg_sync_i),
     .mpeg_clk_6MHz_out(mpeg_clk_6MHz_out_o),
     .mpeg_data_8_out(mpeg_data_8_out_o),
     .mpeg_sync_out(mpeg_sync_out_o),
     .mpeg_valid_out(mpeg_valid_out_o)
     );
  
  always #(CLK_HALF_PERIOD_NS) begin
    sys_clk_i = ~sys_clk_i;
  end

  always #(MPEG_CLK_HALF_PERIOD_NS) begin
    mpeg_clk_6MHz_i = ~mpeg_clk_6MHz_i;
  end
  
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars();

    rst_n_i = 1'b0;
    sys_clk_i = 1'b0;
    mpeg_clk_6MHz_i = 1'b0;
    mpeg_sync_i = 1'b0;

    running_i = 1'b0;

    pb_w_data_i = '0;
    pb_w_addr_i = '0;
    pb0_w_en_i = 1'b0;
    pb1_w_en_i = 1'b0;

    pb_sel = 1'b0;
    start = 1'b1;

    #(10*MPEG_CLK_HALF_PERIOD_NS);
    @(posedge sys_clk_i);
    rst_n_i = 1'b1;
    running_i = 1'b1;

    // @(posedge packet_done_pulse_o);
    // @(posedge packet_done_pulse_o);
    // @(posedge packet_done_pulse_o);
    // @(posedge packet_done_pulse_o);

    repeat (10) @(posedge output_record_done);
    
    $finish;
  end // initial begin

  reg pb_sel;
  reg start;
  reg done;
    
  always_ff @ (posedge sys_clk_i) begin
    if (running_i) begin
      if (packet_done_pulse_o) begin
        start <= 1'b1;
      end
      else if (start) begin
        if (pb0_w_en_i || pb1_w_en_i) begin
          pb0_w_en_i <= 1'b0;
          pb1_w_en_i <= 1'b0;
          pb_w_addr_i <= pb_w_addr_i + 1'b1;
        end
        else if (pb_w_addr_i == 47) begin
          pb_sel <= ~pb_sel;
          pb_w_addr_i <= '0;
          done <= 1'b1;
          start <= 1'b0;
        end
        else begin
          pb_w_data_i <= {26'h3fffffC, pb_w_addr_i}; //packet_data[i];
          if (pb_sel) begin
            pb1_w_en_i <= 1'b1;
          end
          else begin
            pb0_w_en_i <= 1'b1;
          end
        end
      end // if (start)
    end
  end // always_ff @ (posedge sys_clk_i)

  reg [7:0] counter;   // 8 bits is enough for 0–199

  always @(posedge mpeg_clk_6MHz_i) begin
    if (counter == 199) begin
      counter <= '0;
      mpeg_sync_i <= 1'b1;    // pulse high for 1 clock
    end 
    else begin
      counter <= counter + 1'b1;
      mpeg_sync_i <= 1'b0;
    end
  end

  
  wire output_record_done;
  wire [7:0] buffer_output [187:0];

  mpeg_behavioural_recorder 
    #(.MPEG_DIRECTION("Output"))
  mpeg_behavioural_recorder_output
    (
     .mpeg_clk(mpeg_clk_6MHz_out_o),
     .mpeg_data(mpeg_data_8_out_o),
     .mpeg_sync(mpeg_sync_out_o),
     .mpeg_valid(mpeg_valid_out_o),
     .buffer_out(buffer_output),
     .done(output_record_done)
     );
  
endmodule // mpeg_playback_tb

/* verilator lint_off DECLFILENAME */
module mpeg_behavioural_recorder
  #(
     parameter MPEG_DIRECTION = "Input"
    )
  (
    input wire        mpeg_clk,
    input wire [7:0]  mpeg_data,
    input wire        mpeg_sync,
    input wire        mpeg_valid,
    output wire [7:0] buffer_out [187:0],
    output reg done
   );

  reg [7:0] buffer0 [187:0];
  reg [7:0] buffer1 [187:0];

  reg       read_buffer1;
  reg       write_buffer1;

  assign buffer_out = read_buffer1 ? buffer1 : buffer0;
  
  integer   i;
  integer   packet_count;
  
  always begin
    @ (posedge mpeg_valid);
    packet_count += 1;
    $display("%s: Recording packet %0d to buffer: %0d", MPEG_DIRECTION, packet_count, write_buffer1);
    done = 1'b0;
    for (i = 0; i < 188; i += 1) begin
      @ (posedge mpeg_clk) begin
	if (write_buffer1) begin
	  buffer1[i] = mpeg_data;
	end
	else begin
	  buffer0[i] = mpeg_data;
	end
      end
    end // for (i = 0; i < 188; i += 1)
    read_buffer1 = ~read_buffer1;
    write_buffer1 = ~write_buffer1;
    done = 1'b1;
  end

  initial begin
    packet_count = 0;
    read_buffer1 = 1'b1;
    write_buffer1 = 1'b0;
    done = 1'b0;
  end
  
endmodule // mpeg_behavioural_recorder
