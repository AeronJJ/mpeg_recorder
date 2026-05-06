`timescale 1ns/100ps

module mpeg_playback_avalon_mm_master_read_tb;

  localparam CLK_FREQ = 100E6;
  localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;

  localparam DATA_WIDTH = 32;
  localparam ADDR_WIDTH = 32;
  localparam NUM_BYTES  = DATA_WIDTH / 8;

  localparam BUF0_BASE_ADDR = 32'h32000000;
  localparam BUFFER_LENGTH  = 32'h06400000;
  localparam BUFFER_OFFSET = 32'd36;
  
  localparam BUF0_LAST_WORD_ADDR =
             BUF0_BASE_ADDR + BUFFER_LENGTH - 32'd4;

  localparam TEST_CLK_CYCLES = 32'h12345678;

  /* verilator lint_off UNUSEDSIGNAL */
  reg        clk_i;
  reg        rst_i;
  wire [ADDR_WIDTH - 1:0] address_o;
  wire [NUM_BYTES - 1:0]  burstcount_o;
  reg [DATA_WIDTH - 1:0]  readdata_i;
  wire [NUM_BYTES - 1:0]  byteenable_o;
  wire                    read_o;
  reg                     waitrequest_i;
  reg                     readdatavalid_i;
  reg                     en_i;
  reg                     packet_done_i;
  wire                    new_clk_o;
  wire [DATA_WIDTH - 1:0] w_data_o;
  wire [5:0]              w_addr_o;
  wire                    w_en_pb0_o;
  wire                    w_en_pb1_o;
  reg                     buffer0_filled_i;
  reg                     buffer1_filled_i;
  wire                    buffer0_fill_request_irq_o;
  wire                    buffer1_fill_request_irq_o;
  reg                     buffer0_fill_request_irq_received_i;
  reg                     buffer1_fill_request_irq_received_i;
  wire                    init_done_o;

  wire [31:0]             mpeg_sync_clk_cycle_count_o;

  // DUT
  mpeg_playback_avalon_mm_master_read
    mpeg_playback_avalon_mm_master_read_dut
      (
       .clk(clk_i),
       .rst(rst_i),
       .address(address_o),
       .burstcount(burstcount_o),
       .readdata(readdata_i),
       .byteenable(byteenable_o),
       .read(read_o),
       .waitrequest(waitrequest_i),
       .readdatavalid(readdatavalid_i),
       .en(en_i),
       .packet_done(packet_done_i),
       .new_clk(new_clk_o),
       .w_data(w_data_o),
       .w_addr(w_addr_o),
       .w_en_pb0(w_en_pb0_o),
       .w_en_pb1(w_en_pb1_o),
       .buffer0_filled(buffer0_filled_i),
       .buffer1_filled(buffer1_filled_i),
       .buffer0_fill_request_irq(buffer0_fill_request_irq_o),
       .buffer1_fill_request_irq(buffer1_fill_request_irq_o),
       .buffer0_fill_request_irq_received(buffer0_fill_request_irq_received_i),
       .buffer1_fill_request_irq_received(buffer1_fill_request_irq_received_i),
       .init_done(init_done_o),
       .mpeg_sync_clk_cycle_count(mpeg_sync_clk_cycle_count_o)
       );

  // Write pulse counter

  int wr_count;

  always @(posedge w_en_pb0_o) begin
    wr_count <= wr_count + 1'b1;
  end

  // Clock

  always #(CLK_HALF_PERIOD_NS) begin
    clk_i = ~clk_i;
  end

  // Avalon-MM simple read model

  typedef struct packed {
    logic [ADDR_WIDTH-1:0] addr;
  } read_req_t;

  read_req_t pending_req;

  int latency_counter;

  always_ff @(posedge clk_i) begin

    readdatavalid_i <= 0;

    // Accept read immediately
    if (read_o && !waitrequest_i) begin
      pending_req.addr <= address_o;
      latency_counter  <= 2;
    end

    // Generate response
    if (latency_counter > 0) begin

      latency_counter <= latency_counter - 1;

      if (latency_counter == 1) begin

        // ------------------------------------------------------
        // Special case:
        // final DDR word contains MPEG clock cycle count
        // ------------------------------------------------------

        if (pending_req.addr == BUF0_LAST_WORD_ADDR) begin
          readdata_i <= TEST_CLK_CYCLES;
        end
        else begin
          readdata_i <= pending_req.addr ^ 32'hA5A5A5A5;
        end

        readdatavalid_i <= 1;
      end
    end
  end

  // Always ready

  initial waitrequest_i = 0;

  // IRQ handling model

  always_ff @(posedge clk_i) begin
    buffer0_fill_request_irq_received_i
      <= buffer0_fill_request_irq_o;

    buffer1_fill_request_irq_received_i
      <= buffer1_fill_request_irq_o;
  end

  // Stimulus

  initial begin

    $dumpfile("waves.vcd");
    $dumpvars();

    // Init
    clk_i = 0;
    rst_i = 1;
    en_i  = 0;
    packet_done_i = 0;
    buffer0_filled_i = 0;
    buffer1_filled_i = 0;
    buffer0_fill_request_irq_received_i = 0;
    buffer1_fill_request_irq_received_i = 0;
    readdata_i = 0;
    readdatavalid_i = 0;
    wr_count = 0;

    repeat (5) @(posedge clk_i);

    rst_i = 0;

    $display("Starting test...");

    // Enable DUT
    en_i = 1;

    // Simulate buffer0 being filled after IRQ
    wait (buffer0_fill_request_irq_o);

    $display("Buffer0 fill requested");

    repeat (10) @(posedge clk_i);

    buffer0_filled_i = 1;

    // Wait for init_done
    wait (init_done_o);

    $display("Init done");

    // FORCE DUT ADDRESS TO FINAL MPEG packet

    @(posedge clk_i);

    mpeg_playback_avalon_mm_master_read_dut.address = BUF0_BASE_ADDR + BUFFER_LENGTH - BUFFER_OFFSET - 188;

    // Trigger packet read
    packet_done_i = 1;

    @(posedge clk_i);

    packet_done_i = 0;

    // Wait for read transaction to complete
    @ (posedge (mpeg_playback_avalon_mm_master_read_dut.current_state == 4'd5));
    repeat (10) @(posedge clk_i);

    // release mpeg_playback_avalon_mm_master_read_dut.address;

    // SELF-CHECK

    if (mpeg_sync_clk_cycle_count_o == TEST_CLK_CYCLES) begin

      $display("\nPASS:");
      $display("mpeg_sync_clk_cycle_count_o = 0x%08x",
               mpeg_sync_clk_cycle_count_o);

    end
    else begin

      $display("\nFAIL:");
      $display("Expected 0x%08x, got 0x%08x",
             TEST_CLK_CYCLES,
             mpeg_sync_clk_cycle_count_o);

    end

    // Ensure metadata word was NOT written into PB RAM
    if (w_en_pb0_o || w_en_pb1_o) begin
      $display("FAIL: metadata word incorrectly written to PB");
    end

    repeat (20) @(posedge clk_i);

    $display("\nTotal w_en_pb0 pulses: %0d", wr_count);
    $display("Test complete");

    $finish;
  end

  // Debug prints

  always_ff @(posedge clk_i) begin

    if (read_o && !waitrequest_i)
      $display("[%0t] READ issued @ 0x%08x",
               $time,
               address_o);

    if (readdatavalid_i)
      $display("[%0t] READ data = 0x%08x",
               $time,
               readdata_i);

    if (w_en_pb0_o || w_en_pb1_o)
      $display("[%0t] WRITE PB%0d addr=%0d data=0x%08x",
               $time,
               w_en_pb1_o,
               w_addr_o,
               w_data_o);
  end

endmodule
