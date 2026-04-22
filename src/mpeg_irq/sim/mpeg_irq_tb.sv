`timescale 1ns/100ps
module mpeg_irq_tb;
  
  localparam CLK_FREQ = 100E6;
  localparam CLK_HALF_PERIOD_NS = 5E8/CLK_FREQ;
  
  
  reg        clk_i;
  reg        rst_n_i;
  reg        en_interrupt_i;
  wire       irq_o;
  reg        irq_reset_i;
  

  mpeg_irq dut_mpeg_irq 
    (
     .clk(clk_i),
     .rst_n(rst_n_i),
     .en_interrupt(en_interrupt_i),
     .irq(irq_o),
     .irq_reset(irq_reset_i)
     );

  always #(CLK_HALF_PERIOD_NS) begin
    clk_i = ~clk_i;
  end

  // Reference model
  logic ref_irq;
  logic irq_reset_d;

  always_ff @ (posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin
      ref_irq <= 0;
      irq_reset_d <= 0;
    end 
    else begin
      logic irq_reset_edge;
      irq_reset_edge = irq_reset_i ^ irq_reset_d;

      irq_reset_d <= irq_reset_i;

      if (irq_reset_edge)
        ref_irq <= 0;
      else if (en_interrupt_i)
        ref_irq <= 1;
    end
  end

  // Checker
  always @ (posedge clk_i or negedge rst_n_i) begin
    if (~rst_n_i) begin

    end
    else begin
      if (irq_o !== ref_irq) begin
        $error("Mismatch at time %0t: irq=%0b expected=%0b",
               $time, irq_o, ref_irq);
        $fatal;
      end
    end
  end

  // Generate reset
  int delay_cycles;
  always @ (posedge irq_o) begin 
    delay_cycles <= $urandom_range(10, 50);
    repeat (delay_cycles) @(posedge clk_i);
    irq_reset_i <= ~irq_reset_i;
  end

  // Stimulus
  int delay_cycles_d;
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars();
    
    // Init
    rst_n_i = 0;
    en_interrupt_i = 0;
    irq_reset_i = 0;
    
    repeat (5) @(posedge clk_i);
    rst_n_i = 1;

    // 1. Trigger interrupt
    @(posedge clk_i);
    en_interrupt_i = 1;
    @(posedge clk_i);
    en_interrupt_i = 0;
    @(negedge irq_o);
    
    // 2. Trigger interrupt again
    @(posedge clk_i);
    en_interrupt_i = 1;
    @(posedge clk_i);
    en_interrupt_i = 0;
    @(negedge irq_o);

    // Random stress test
    repeat (200) begin
      @(posedge clk_i);
      en_interrupt_i = 1'($urandom_range(0,1));
      @(posedge clk_i);
      en_interrupt_i = 1'b0;
      delay_cycles_d = $urandom_range(10, 50);
      repeat (delay_cycles_d) @(posedge clk_i);
      if (en_interrupt_i) begin
        @(negedge irq_o);
      end
    end

    // Done
    $display("TEST PASSED");
    $finish;
  end
  
endmodule // mpeg_irq_tb
