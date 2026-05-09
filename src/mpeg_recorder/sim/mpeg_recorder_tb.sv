`timescale 1ns/100ps
module mpeg_recorder_tb;

  localparam CLK_FREQ = 100E6;
  localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;

  localparam MPEG_CLK_FREQ = 6E6;
  localparam MPEG_CLK_HALF_PERIOD_NS = 5E8/MPEG_CLK_FREQ; 

  localparam MPEG_DATA_WIDTH = 8;
  localparam MPEG_MEM_WIDTH = 4;
  localparam MPEG_MEM_LENGTH = MPEG_DATA_WIDTH * MPEG_MEM_WIDTH;
  localparam MPEG_ADDR_WIDTH = 6;
  localparam MPEG_PACKET_LENGTH_BYTES = 188;
  localparam MPEG_PACKET_LENGTH = MPEG_PACKET_LENGTH_BYTES/MPEG_MEM_WIDTH;
    
  reg                          rst_n_i;
  reg                          mpeg_clk_6MHz_i;
  reg [MPEG_DATA_WIDTH - 1:0]  mpeg_data_8_i;
  reg                          mpeg_sync_i;
  reg                          mpeg_valid_i;
  reg                          sys_clk_40MHz_i;
  reg                          start_i;
  reg                          stop_i;
  reg [MPEG_ADDR_WIDTH - 1:0]  r_addr_i;
  reg                          r_en_i;  

  wire                         mpeg_clk_6MHz_out_o;
  wire [MPEG_DATA_WIDTH - 1:0] mpeg_data_8_out_o;
  wire                         mpeg_sync_out_o;
  wire                         mpeg_valid_out_o;
  wire [MPEG_MEM_LENGTH - 1:0] r_data_32_o;
  wire                         packet_done_out_o;
  wire                         recording_o;
    
  mpeg_recorder
    #(
      .MPEG_DATA_WIDTH(MPEG_DATA_WIDTH),
      .MPEG_MEM_WIDTH(MPEG_MEM_WIDTH),
      .MPEG_ADDR_WIDTH(MPEG_ADDR_WIDTH),
      .MPEG_PACKET_LENGTH_BYTES(MPEG_PACKET_LENGTH_BYTES)
      )
  dut_mpeg_recorder
    (
     .rst_n(rst_n_i),
     .mpeg_clk_6MHz(~mpeg_clk_6MHz_i),
     .mpeg_data_8(mpeg_data_8_i),
     .mpeg_sync(mpeg_sync_i),
     .mpeg_valid(mpeg_valid_i),
     .sys_clk(sys_clk_40MHz_i),
     .start(start_i),
     .stop(stop_i),
     .r_data_32(r_data_32_o),
     .r_addr(r_addr_i),
     .r_en(r_en_i),
     .packet_done_out(packet_done_out_o),
     .recording(recording_o)
     );

  always begin
    fork
      while (~mpeg_sync_i) begin
	#1;
      end
      forever begin
	#(MPEG_CLK_HALF_PERIOD_NS) mpeg_clk_6MHz_i = ~mpeg_clk_6MHz_i;
      end
    join_any
    disable fork;
    
    // @ (posedge mpeg_sync_i);
    mpeg_clk_6MHz_i = 1'b0;
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
    start_i = 1'b1;

    #(6 * MPEG_CLK_HALF_PERIOD_NS);
    
    @ (posedge mpeg_clk_6MHz_i);
    
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
      $display("Reading input buffer %d, output buffer %d", mpeg_behavioural_recorder_input.read_buffer1, mpeg_behavioural_recorder_output.read_buffer1);
      if (buffer_input != buffer_output) begin
	// $display("Packet mismatch detected between input packet %0d and output packet %0d", );
	
	$display("Packet mismatch detected");
	packet_errors += 1;
      end
    end
  end // always

  reg read_packet;
  int word_counter;
  always @ (posedge sys_clk_40MHz_i) begin
    if (packet_done_out_o) begin
      read_packet <= 1'b1;
      r_addr_i <= '1;      
    end
    else if (r_addr_i == 47) begin
      read_packet <= 1'b0;
      r_en_i <= 1'b0;
      r_addr_i <= '1;      
    end
    else if (read_packet) begin
      r_en_i <= 1'b1;
      r_addr_i <= r_addr_i + 1;
    end
  end // always @ (posedge sys_clk_40MHz_i)

  // Store read data to check against
  reg [31:0] packet_buffer_data_check [46:0];
  reg        checked;
  reg [5:0]  data_check_addr;
  reg        r_en_d;
    
  always @ (posedge sys_clk_40MHz_i) begin
    r_en_d <= r_en_i;
    if (r_en_d) begin 
      checked <= 1'b0; 
      packet_buffer_data_check[data_check_addr] <= r_data_32_o; 
      data_check_addr <= data_check_addr + 1'b1; 
    end 
    else if (~checked) begin 
      // Compare read data against input data 
      checked <= 1'b1; 
      data_check_addr <= '0;
      for (int i = 0; i < 47; i++) begin
        logic [31:0] expected_val;
        
        expected_val = {
                        buffer_input[i*4 + 3],
                        buffer_input[i*4 + 2],
                        buffer_input[i*4 + 1],
                        buffer_input[i*4 + 0]
                        };
        
        if (packet_buffer_data_check[i] !== expected_val) begin
          $display("Mismatch at %0d: got %h expected %h",
                   i, packet_buffer_data_check[i], expected_val);
        end
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
    #1;
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
