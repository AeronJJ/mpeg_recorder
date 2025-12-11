`timescale 1ns/100ps
module mpeg_recorder_tb;

   localparam CLK_FREQ = 40E6;
   localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;

   localparam MPEG_CLK_FREQ = 6E6;
   localparam MPEG_CLK_HALF_PERIOD_NS = 5E8/MPEG_CLK_FREQ; 

   localparam MPEG_DATA_WIDTH = 8;
   localparam MPEG_MEM_LENGTH = 32;
      
   reg	      rst_n_i;
   reg	      mpeg_clk_6MHz_i;
   reg [MPEG_DATA_WIDTH - 1:0] mpeg_data_8_i;
   reg			       mpeg_sync_i;
   reg			       mpeg_valid_i;
   reg			       sys_clk_40MHz_i;
   reg			       start_i;
   reg			       stop_i;

   wire			       mpeg_clk_6MHz_out_o;
   wire [MPEG_DATA_WIDTH - 1:0]	mpeg_data_8_out_o;
   wire				mpeg_sync_out_o;
   wire				mpeg_valid_out_o;
   
   

   mpeg_recorder dut_mpeg_recorder
     (
      .rst_n(rst_n_i),
      .mpeg_clk_6MHz(~mpeg_clk_6MHz_i),
      .mpeg_data_8(mpeg_data_8_i),
      .mpeg_sync(mpeg_sync_i),
      .mpeg_valid(mpeg_valid_i),
      .sys_clk_40MHz(sys_clk_40MHz_i),
      .start(start_i),
      .stop(stop_i),
      .mpeg_clk_6MHz_out(mpeg_clk_6MHz_out_o),
      .mpeg_data_8_out(mpeg_data_8_out_o),
      .mpeg_sync_out(mpeg_sync_out_o),
      .mpeg_valid_out(mpeg_valid_out_o)
      );

   always begin
      while (~mpeg_sync_i) begin
	 #1;
      end
      // @ (posedge mpeg_sync_i);
      mpeg_clk_6MHz_i = 1'b1;
      fork
	 forever begin
	    #(MPEG_CLK_HALF_PERIOD_NS) mpeg_clk_6MHz_i = ~mpeg_clk_6MHz_i;
	 end
	 @ (posedge mpeg_sync_i);
      join_any
      disable fork;
   end

   always #(CLK_HALF_PERIOD_NS) begin
      sys_clk_40MHz_i = ~sys_clk_40MHz_i;
   end

   // always #(MPEG_CLK_HALF_PERIOD_NS) begin
   //    mpeg_clk_6MHz_i = ~mpeg_clk_6MHz_i;
   // end
   
   initial begin
      $dumpfile("waves.vcd");
      $dumpvars();

      rst_n_i = 1'b0;
      mpeg_clk_6MHz_i = 1'b0;
      sys_clk_40MHz_i = 1'b0;
      
      start_i = 1'b0;

      #(6 * MPEG_CLK_HALF_PERIOD_NS);

      rst_n_i = 1'b1;

      #(6 * MPEG_CLK_HALF_PERIOD_NS);
      
      @ (posedge mpeg_clk_6MHz_i);
      
      start_i = 1'b1;
      #(6 * MPEG_CLK_HALF_PERIOD_NS);
      
      @ (posedge vcd_done);
      $display("Total packets recorded: %0d", total_packets);
      $display("Total packet errors: %0d", packet_errors);
      $display("Error rate: %0f\%", (packet_errors * 1.0)/total_packets);
      $finish;
   end // initial begin
   
   // Verify output matches input //

   wire output_record_done;
   wire [7:0] buffer_input [187:0];
   wire [7:0] buffer_output [187:0];
   
   
   mpeg_behavioural_recorder 
     #(.MPEG_DIRECTION("Input "))
   mpeg_behavioural_recorder_input
     (
      .mpeg_clk(mpeg_clk_6MHz_i),
      .mpeg_data(mpeg_data_8_i),
      .mpeg_sync(mpeg_sync_i),
      .mpeg_valid(mpeg_valid_i),
      .buffer_out(buffer_input),
      .done()
      );

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

   integer total_packets;
   integer packet_errors;
   
   always begin
      @ (posedge output_record_done) begin
	 total_packets += 1;
	 if (buffer_input != buffer_output) begin
	    // $display("Packet mismatch detected between input packet %0d and output packet %0d", );
	    packet_errors += 1;
	 end
      end
   end
   
   // //
   

   /* INSERT */
   
endmodule // mpeg_recorder_tb

module mpeg_behavioural_recorder
  #(
    parameter MPEG_DIRECTION = "Input"
    )
  (
   input wire	     mpeg_clk,
   input wire [7:0]  mpeg_data,
   input wire	     mpeg_sync,
   input wire	     mpeg_valid,
   output wire [7:0] buffer_out [187:0],
   output reg	     done
   );

   reg [7:0] buffer0 [187:0];
   reg [7:0] buffer1 [187:0];

   reg	     read_buffer1;
   reg	     write_buffer1;

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
