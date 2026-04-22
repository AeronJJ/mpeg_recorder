`timescale 1ns/100ps
module mpeg_recorder_avalon_mm_master_write_tb;

  localparam CLK_FREQ = 100E6;
  localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;

  localparam BUFFER_LENGTH = 32'h00006400;
  localparam BUF0_BASE_ADDR = 32'h32000000;
  localparam BUF1_BASE_ADDR = BUF0_BASE_ADDR + BUFFER_LENGTH;

  localparam ADDR_WIDTH = 32;
  localparam DATA_WIDTH = 32;
  localparam NUM_BYTES = DATA_WIDTH / 8;
  
  /* verilator lint_off UNUSEDSIGNAL */
  reg        clk_i;
  reg        rst_i;
  wire [ADDR_WIDTH-1:0] address_o;
  wire [3:0]            burstcount_o;
  wire [DATA_WIDTH-1:0] writedata_o;
  wire [3:0]            byteenable_o;
  wire                  write_o;
  reg                   waitrequest_i;
  reg                   en_i;
  reg                   packet_done_i;
  reg [DATA_WIDTH-1:0]  r_data_i;
  wire [5:0]            r_addr_o;
  wire                  r_en_o;
  wire                  buffer0_done_irq_o;
  wire                  buffer1_done_irq_o;
  reg                   buffer0_done_irq_received_i;
  reg                   buffer1_done_irq_received_i;
  /* verilator lint_on UNUSEDSIGNAL */
  
  mpeg_recorder_avalon_mm_master_write 
    #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH),
      .NUM_BYTES(NUM_BYTES),
      .BUF0_BASE_ADDR(BUF0_BASE_ADDR),
      .BUF1_BASE_ADDR(BUF1_BASE_ADDR),
      .BUFFER_LENGTH(BUFFER_LENGTH)
      )
  dut_mpeg_recorder_avalon_mm_master_write 
    (
     .clk(clk_i),
     .rst(rst_i),
     .address(address_o),
     .burstcount(burstcount_o),
     .writedata(writedata_o),
     .byteenable(byteenable_o),
     .write(write_o),
     .waitrequest(waitrequest_i),
     .en(en_i),
     .packet_done(packet_done_i),
     .r_data(r_data_i),
     .r_addr(r_addr_o),
     .r_en(r_en_o),
     .buffer0_done_irq(buffer0_done_irq_o),
     .buffer1_done_irq(buffer1_done_irq_o),
     .buffer0_done_irq_received(buffer0_done_irq_received_i),
     .buffer1_done_irq_received(buffer1_done_irq_received_i)
     );

  always #(CLK_HALF_PERIOD_NS) begin
    clk_i = ~clk_i;
  end

  always @ (posedge write_o) begin
    waitrequest_i <= 1'b1;
    #(4*CLK_HALF_PERIOD_NS);
    waitrequest_i <= 1'b0;
  end

  always @ (posedge r_en_o) begin
    r_data_i <= 32'hF0F00000 + 32'(r_addr_o);
  end

  // Generate irq reset
  int delay_cycles_0;
  always @ (posedge buffer0_done_irq_o) begin 
    delay_cycles_0 <= $urandom_range(10, 50);
    repeat (delay_cycles_0) @(posedge clk_i);
    buffer0_done_irq_received_i <= ~buffer0_done_irq_received_i;
  end
  
  int delay_cycles_1;
  always @ (posedge buffer1_done_irq_o) begin 
    delay_cycles_1 <= $urandom_range(10, 50);
    repeat (delay_cycles_1) @(posedge clk_i);
    buffer1_done_irq_received_i <= ~buffer1_done_irq_received_i;
  end

  time start_time;
  
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars();

    clk_i = 1'b0;
    waitrequest_i = 1'b0;
    en_i = 1'b0;
    packet_done_i = 1'b0;
    r_data_i = 32'hF0F00000;
    buffer0_done_irq_received_i = 1'b0;
    buffer1_done_irq_received_i = 1'b0;
        
    rst_i = 1'b1;
    #(10*CLK_HALF_PERIOD_NS);
    rst_i = 1'b0;
    
    #(10*CLK_HALF_PERIOD_NS);
    en_i = 1'b1;

    #(10*CLK_HALF_PERIOD_NS);
    packet_done_i = 1'b1;
    #(2*CLK_HALF_PERIOD_NS);
    packet_done_i = 1'b1;
    
    #(5000*CLK_HALF_PERIOD_NS);
    @ (posedge buffer0_done_irq_o);
    start_time = $time;
    $display("Buffer0 IRQ detected");
    $display("Read addr = %d\n", r_addr_o);
    @ (negedge buffer0_done_irq_o);
    $display("Time irq high: %d\n", $time - start_time);
    
    @ (posedge buffer1_done_irq_o);
    start_time = $time;
    $display("Buffer1 IRQ detected");    
    $display("Read addr = %d\n", r_addr_o);
    @ (negedge buffer1_done_irq_o);
    $display("Time irq high: %d\n", $time - start_time);
    
        
    $finish;
  end
  
endmodule // mpeg_recorder_avalon_mm_master_write_tb
