`default_nettype none
module mpeg_sync_gen 
  (
   input wire        rst_n,
   input wire        sys_clk,
   input wire        mpeg_clk,
   input wire        en,
   input wire [31:0] clk_cycles_count,
   output reg        mpeg_sync
   );

  // Calculation:
  /*
   last_time = No_MPEG_PACKETS * time_per_packet
   time_per_packet = last_time / No_MPEG_PACKETS
   
   No_MPEG_CLK_CYCLES = time_per_packet / MPEG_CLK_PERIOD
   No_MPEG_CLK_CYCLES = time_per_packet * MPEG_CLK_FREQ
   
   No_MPEG_CLK_CYCLES = last_time * MPEG_CLK_FREQ / No_MPEG_PACKETS
   
   No_MPEG_PACKETS = 557753
   MPEG_CLK_FREQ = 6000000
   
   Calculated in software...
   
   */

  reg [31:0] clk_cycles_count_store_sys;
  reg        update_toggle_sys;

  wire [31:0] next_value = (clk_cycles_count > 190) ? clk_cycles_count : 32'd190;

  // Capture value in sys_clk domain
  always_ff @ (posedge sys_clk or negedge rst_n) begin
    if (~rst_n) begin
      clk_cycles_count_store_sys <= 32'd190;
      update_toggle_sys <= 1'b0;
    end
    else begin
      if (clk_cycles_count_store_sys != next_value) begin
        clk_cycles_count_store_sys <= next_value;
        update_toggle_sys <= ~update_toggle_sys;
      end
    end
  end

  // Synchronise toggle into MPEG clock domain //
  reg update_toggle_mpeg_d0;
  reg update_toggle_mpeg_d1;

  always_ff @ (posedge mpeg_clk or negedge rst_n) begin
    if (~rst_n) begin
      update_toggle_mpeg_d0 <= 1'b0;
      update_toggle_mpeg_d1 <= 1'b0;
    end
    else begin
      update_toggle_mpeg_d0 <= update_toggle_sys;
      update_toggle_mpeg_d1 <= update_toggle_mpeg_d0;
    end
  end

  wire update_pulse_mpeg = update_toggle_mpeg_d0 ^ update_toggle_mpeg_d1;
  // //

  // Sample clk cycles into mpeg clock domain //
  reg [31:0] clk_cycles_count_mpeg;

  always_ff @ (posedge mpeg_clk or negedge rst_n) begin
    if (~rst_n) begin
      clk_cycles_count_mpeg <= 32'd190;
    end
    else if (update_pulse_mpeg) begin
      clk_cycles_count_mpeg <= clk_cycles_count_store_sys;
    end
  end
  // //

  // Generate mpeg_sync //
  reg [31:0] counter;
  
  always_ff @ (negedge mpeg_clk or negedge rst_n) begin
    if (~rst_n) begin
      mpeg_sync <= 1'b0;
      counter <= '0;      
    end
    else if (en) begin 
      if (counter == '0) begin
        counter <= clk_cycles_count_mpeg;
        mpeg_sync <= 1'b1;
      end
      else begin
        counter <= counter - 1'b1;
        mpeg_sync <= 1'b0;
      end
    end
    else begin
      counter <= clk_cycles_count_mpeg;
      mpeg_sync <= 1'b0;
    end
  end
  // //
  
endmodule // mpeg_sync_gen
`default_nettype wire
  
