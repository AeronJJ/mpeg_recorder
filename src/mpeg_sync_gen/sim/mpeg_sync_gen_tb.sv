`timescale 1ns/100ps
module mpeg_sync_gen_tb;
  
  localparam CLK_FREQ = 100E6;
  localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;
  localparam MPEG_CLK_FREQ = 6E6;
  localparam MPEG_CLK_HALF_PERIOD_NS = 5E8/MPEG_CLK_FREQ;
  
  reg        rst_n_i;
  reg        sys_clk_i;
  reg        mpeg_clk_i;
  reg        en_i;
  reg [31:0] clk_cycles_count_i;
  wire       mpeg_sync_o;
  

  mpeg_sync_gen dut_mpeg_sync_gen 
    (
     .rst_n(rst_n_i),
     .sys_clk(sys_clk_i),
     .mpeg_clk(mpeg_clk_i),
     .en(en_i),
     .clk_cycles_count(clk_cycles_count_i),
     .mpeg_sync(mpeg_sync_o)
     );

  // 6 MHz clock
  always #(MPEG_CLK_HALF_PERIOD_NS) begin
    mpeg_clk_i = ~mpeg_clk_i;
  end

  // 100 MHz clock
  always #(CLK_HALF_PERIOD_NS) begin
    sys_clk_i = ~sys_clk_i;
  end

  // Test configuration
  localparam int TEST_COUNT = 10;

  int            expected_period;
  int            pulse_count;
  int            cycle_count;
  int            error_count;

  // Self-checking monitor
  always @ (posedge mpeg_clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      cycle_count <= 0;
    end
    else if (~en_i) begin
      cycle_count <= 0;
    end
    else begin
      cycle_count <= cycle_count + 1;

      if (mpeg_sync_o) begin
        pulse_count <= pulse_count + 1;

        // First pulse establishes reference
        if (pulse_count > 0) begin

          if (cycle_count != expected_period) begin
            $display("Incorrect sync period. Expected %0d cycles, got %0d",
                   expected_period,
                   cycle_count);

            error_count <= error_count + 1;
          end
          else begin
            $display("PASS: sync period = %0d cycles", cycle_count);
          end
        end

        cycle_count <= 0;
      end
    end
  end

  // Stimulus
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars();
    
    rst_n_i            = 0;
    sys_clk_i          = 0;
    mpeg_clk_i         = 0;
    en_i               = 0;
    clk_cycles_count_i = 0;

    pulse_count      = 0;
    cycle_count      = 0;
    error_count      = 0;

    repeat (5) @(posedge mpeg_clk_i);

    rst_n_i = 1;

    repeat (2) @(posedge mpeg_clk_i);

    // Test 1
    expected_period    = 250;
    clk_cycles_count_i = expected_period;
    en_i               = 1;

    $display("\nTEST 1: clk_cycles_count = %0d\n", expected_period);

    wait (pulse_count == TEST_COUNT);

    // Test 2
    en_i = 1;
    repeat (5) @(posedge mpeg_clk_i);

    pulse_count      = 0;
    cycle_count      = 0;

    expected_period    = 380;
    clk_cycles_count_i = expected_period;
    en_i               = 1;

    $display("\nTEST 2: clk_cycles_count = %0d\n", expected_period);

    wait (pulse_count == TEST_COUNT);

    // Test 3
    en_i = 0;
    repeat (5) @(posedge mpeg_clk_i);

    pulse_count      = 0;
    cycle_count      = 0;

    expected_period    = 190;
    clk_cycles_count_i = 24;
    en_i               = 1;

    $display("\nTEST 3: clk_cycles_count = %0d\n", expected_period);

    wait (pulse_count == TEST_COUNT);

    // Finish
    repeat (10) @(posedge mpeg_clk_i);

    if (error_count == 0) begin
      $display("\n========================================");
      $display("ALL TESTS PASSED");
      $display("========================================\n");
    end
    else begin
      $display("\n========================================");
      $display("TEST FAILED WITH %0d ERRORS", error_count);
      $display("========================================\n");
    end

    $finish;
  end
  
endmodule // mpeg_sync_gen_tb
