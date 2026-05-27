`default_nettype none
module mpeg_top_level 
  #(
    parameter MPEG_DATA_WIDTH = 8
    )
  (
   input wire                          mpeg_clk_6MHz,
   input wire [MPEG_DATA_WIDTH - 1:0]  mpeg_data_8,
   input wire                          mpeg_sync,
   input wire                          mpeg_valid,

   input wire                          ref_clk_50MHz,
   input wire                          rst_n,
   input wire                          start_n,
   input wire                          stop_n,
  
   output wire                         mpeg_clk_6MHz_out,
   output wire [MPEG_DATA_WIDTH - 1:0] mpeg_data_8_out,
   output wire                         mpeg_sync_out,
   output wire                         mpeg_valid_out,

   output wire                         lcd_cs_out,
   output wire                         lcd_dcrs_out,
   output wire                         lcd_sdi_out,
   output wire                         lcd_sck_out,
   output wire                         lcd_lcdrst_out,

   input wire                          touch_sdo_in,
   input wire                          touch_irq_in,
   output wire                         touch_cs_out,
   output wire                         touch_sdi_out,
   output wire                         touch_sck_out,
   
   output wire [12:0]                  memory_mem_a,
   output wire [2:0]                   memory_mem_ba,
   output wire                         memory_mem_ck,
   output wire                         memory_mem_ck_n,
   output wire                         memory_mem_cke,
   output wire                         memory_mem_cs_n,
   output wire                         memory_mem_ras_n,
   output wire                         memory_mem_cas_n,
   output wire                         memory_mem_we_n,
   output wire                         memory_mem_reset_n,
   inout wire [7:0]                    memory_mem_dq,
   inout wire                          memory_mem_dqs,
   inout wire                          memory_mem_dqs_n,
   output wire                         memory_mem_odt,
   output wire                         memory_mem_dm,
   input wire                          memory_oct_rzqin,
   output [14:0]                       HPS_DDR3_ADDR, 
   output [2:0]                        HPS_DDR3_BA,
   output                              HPS_DDR3_CAS_N,
   output                              HPS_DDR3_CKE,
   output                              HPS_DDR3_CK_N,
   output                              HPS_DDR3_CK_P,
   output                              HPS_DDR3_CS_N,
   output [3:0]                        HPS_DDR3_DM,
   inout [31:0]                        HPS_DDR3_DQ,
   inout [3:0]                         HPS_DDR3_DQS_N,
   inout [3:0]                         HPS_DDR3_DQS_P,
   output                              HPS_DDR3_ODT,
   output                              HPS_DDR3_RAS_N,
   output                              HPS_DDR3_RESET_N,
   input                               HPS_DDR3_RZQ,
   output                              HPS_DDR3_WE_N,

   output wire [6:0]                   led_test_signal,
   input wire [3:0]                    mode_switch_test
   );

  // PLL //
  wire sys_clk_100MHz;
  wire sys_clk_1MHz;
  wire mpeg_clk_6MHz_playback_in;
  wire pll_locked;
  pll pll0 
    (
     .refclk(ref_clk_50MHz),   //  refclk.clk
     .rst(~rst_n),	     //   reset.reset
     .outclk_0(sys_clk_100MHz), // outclk0.clk
     .outclk_1(sys_clk_1MHz), // outclk1.clk
     .outclk_2(mpeg_clk_6MHz_playback_in), // outclk2.clk
     .locked(pll_locked) // locked.export
     );
  // //
  
  // Gate rst_n behind pll lock //
  wire rst_n_gated;
  assign rst_n_gated = rst_n;
// & pll_locked;
  // // 
  
  // Synchronise start and stop //
  reg start_tmp;
  reg stop_tmp;
  reg start_sync;
  reg stop_sync;
  always_ff @ (posedge mpeg_clk_6MHz or negedge rst_n_gated) begin
    if (~rst_n_gated) begin
      start_tmp <= 1'b1;
      stop_tmp <= 1'b1;
      start_sync <= 1'b1;
      stop_sync <= 1'b1;
    end
    else begin
      start_tmp <= start_n;
      stop_tmp <= stop_n;

      start_sync <= start_tmp;
      stop_sync <= stop_tmp;
    end
  end
  // //

  // Debounce switches //
  wire [3:0] mode_switch_test_db;
  debounce_switches 
    #(
      .CLK_FREQ_HZ(50_000_000),
      .DEBOUNCE_MS(20)
      ) 
  debounce_inst
    (
     .clk    (sys_clk_100MHz),
     .rst_n  (rst_n),
     .sw_in  (mode_switch_test),
     .sw_out (mode_switch_test_db)
     );

  // //

  // MPEG Recorder //
  wire [31:0] r_data_32;
  wire [5:0]  r_addr;
  wire        r_en;
  wire        packet_done;

  wire        mpeg_clk_6MHz_recorder = mpeg_clk_6MHz;
  wire [MPEG_DATA_WIDTH - 1:0] mpeg_data_8_recorder = mpeg_data_8;
  wire                         mpeg_sync_recorder = mpeg_sync;
  wire                         mpeg_valid_recorder = mpeg_valid;

  wire                         recording;
  
  mpeg_recorder
    #(
      .MPEG_DATA_WIDTH(MPEG_DATA_WIDTH)
      )
  mpeg_mpeg_recorder_0
    (
     .rst_n(rst_n_gated),
     .mpeg_clk_6MHz(mpeg_clk_6MHz),
     .mpeg_data_8(mpeg_data_8),
     .mpeg_sync(mpeg_sync),
     .mpeg_valid(mpeg_valid),
     .sys_clk(sys_clk_100MHz),
     .start((~start_sync) && mode[2]),
     .stop(~stop_sync),
     .r_data_32(r_data_32),
     .r_addr(r_addr),
     .r_en(r_en),
     .packet_done_out(packet_done),
     .recording(recording)
     );
  // //

  // MPEG Playback //
  wire [31:0] pb_w_data;
  wire [5:0]  pb_w_addr;
  wire        pb0_w_en;
  wire        pb1_w_en;
  wire        running_playback;
  wire        packet_done_playback;

  wire        mpeg_clk_6MHz_playback;
  wire [MPEG_DATA_WIDTH - 1:0]  mpeg_data_8_playback;
  wire                          mpeg_sync_playback;
  wire                          mpeg_valid_playback;

  wire                          clk_playback;
  wire [31:0]                   mpeg_sync_clk_cycle_count;
      
  mpeg_playback
    #(
      .MPEG_DATA_WIDTH(MPEG_DATA_WIDTH)
      )
  mpeg_mpeg_playback_0
    (
     .sys_clk(clk_playback),
     .rst_n(rst_n_gated),
     .pb_w_data(pb_w_data),
     .pb_w_addr(pb_w_addr),
     .pb0_w_en(pb0_w_en),
     .pb1_w_en(pb1_w_en),
     .running(running_playback),
     .packet_done_pulse(packet_done_playback),
     .mpeg_clk_6MHz(mpeg_clk_6MHz_playback_in),
     .mpeg_clk_6MHz_out(mpeg_clk_6MHz_playback),
     .mpeg_data_8_out(mpeg_data_8_playback),
     .mpeg_sync_out(mpeg_sync_playback),
     .mpeg_valid_out(mpeg_valid_playback),
     .mpeg_sync_clk_cycle_count(mpeg_sync_clk_cycle_count)
     );
  // //

  // MPEG stream output //
  always_comb begin
    case (mode)
      4'b0001: begin
        // Idle
        mpeg_clk_6MHz_out = 1'b0;
        mpeg_data_8_out   = 8'b0;
        mpeg_sync_out     = 1'b0;
        mpeg_valid_out    = 1'b0;
      end

      4'b0010: begin
        // Passthrough
        mpeg_clk_6MHz_out = mpeg_clk_6MHz;
        mpeg_data_8_out   = mpeg_data_8;
        mpeg_sync_out     = mpeg_sync;
        mpeg_valid_out    = mpeg_valid;
      end

      4'b0100: begin
        // Record
        mpeg_clk_6MHz_out = mpeg_clk_6MHz_recorder;
        mpeg_data_8_out   = mpeg_data_8_recorder;
        mpeg_sync_out     = mpeg_sync_recorder;
        mpeg_valid_out    = mpeg_valid_recorder;
      end

      4'b1000: begin
        // Playback
        mpeg_clk_6MHz_out = mpeg_clk_6MHz_playback;
        mpeg_data_8_out   = mpeg_data_8_playback;
        mpeg_sync_out     = mpeg_sync_playback;
        mpeg_valid_out    = mpeg_valid_playback;
      end

      default: begin
        // Treat as idle
        mpeg_clk_6MHz_out = 1'b0;
        mpeg_data_8_out   = 8'b0;
        mpeg_sync_out     = 1'b0;
        mpeg_valid_out    = 1'b0;        
      end
    endcase
  end
  // //

  // LCD //
  wire [3:0] mode; // Onehot (playback, record, passthrough, idle)
  // assign mode = mode_switch_test_db;
  mpeg_user_interface mpeg_user_interface0
    (
     .rst_n(rst_n_gated),
     .sys_clk_100MHz(sys_clk_100MHz),
     .sys_clk_1MHz(sys_clk_1MHz),
     .recording(recording),
     .mode(mode),
     // .mode(),
     .lcd_cs_out(lcd_cs_out),
     .lcd_dcrs_out(lcd_dcrs_out),
     .lcd_sdi_out(lcd_sdi_out),
     .lcd_sck_out(lcd_sck_out),
     .lcd_lcdrst_out(lcd_lcdrst_out),
     .touch_sdo_in(touch_sdo_in),
     .touch_irq_in(touch_irq_in),
     .touch_cs_out(touch_cs_out),
     .touch_sdi_out(touch_sdi_out),
     .touch_sck_out(touch_sck_out)
     );
  // //

  wire [31:0] hps_irq1;
    
  wire [7:0]  lw_dout;
      
  hps u0 
    (
     .clk_clk            ( sys_clk_100MHz),   //            clk.clk
     .memory_mem_a       ( HPS_DDR3_ADDR),    //         memory.mem_a
     .memory_mem_ba      ( HPS_DDR3_BA),      //               .mem_ba
     .memory_mem_ck      ( HPS_DDR3_CK_P),    //               .mem_ck
     .memory_mem_ck_n    ( HPS_DDR3_CK_N),    //               .mem_ck_n
     .memory_mem_cke     ( HPS_DDR3_CKE),     //               .mem_cke
     .memory_mem_cs_n    ( HPS_DDR3_CS_N),    //               .mem_cs_n
     .memory_mem_ras_n   ( HPS_DDR3_RAS_N),   //               .mem_ras_n
     .memory_mem_cas_n   ( HPS_DDR3_CAS_N),   //               .mem_cas_n
     .memory_mem_we_n    ( HPS_DDR3_WE_N),    //               .mem_we_n
     .memory_mem_reset_n ( HPS_DDR3_RESET_N), //               .mem_reset_n
     .memory_mem_dq      ( HPS_DDR3_DQ),      //               .mem_dq
     .memory_mem_dqs     ( HPS_DDR3_DQS_P),   //               .mem_dqs
     .memory_mem_dqs_n   ( HPS_DDR3_DQS_N),   //               .mem_dqs_n
     .memory_mem_odt     ( HPS_DDR3_ODT),     //               .mem_odt
     .memory_mem_dm      ( HPS_DDR3_DM),      //               .mem_dm
     .memory_oct_rzqin   ( HPS_DDR3_RZQ),     //               .oct_rzqin
     .reset_reset_n      ( rst_n_gated),      //          reset.reset_n
     .hps_0_f2h_irq1_irq ( hps_irq1),         // hps_0_f2h_irq1.irq
     .mpeg_recorder_avalon_mm_write_en_en                       ( mode[2]),
     .mpeg_recorder_avalon_mm_write_en_packet_done              ( packet_done),
     .mpeg_recorder_avalon_mm_master_write_0_r_interface_r_data ( r_data_32),
     .mpeg_recorder_avalon_mm_master_write_0_r_interface_r_addr ( r_addr),
     .mpeg_recorder_avalon_mm_master_write_0_r_interface_r_en   ( r_en),
     .mpeg_playback_avalon_mm_master_read_0_en_en               ( mode[3]), // mpeg_playback_avalon_mm_master_read_0_en.en
     .mpeg_playback_avalon_mm_master_read_0_en_packet_done      ( packet_done_playback), // .packet_done
     .mpeg_playback_avalon_mm_master_read_0_en_init_done        ( running_playback), // .init_done
     .mpeg_playback_avalon_mm_master_read_0_w_interface_w_data  ( pb_w_data), //  mpeg_playback_avalon_mm_master_read_0_w_interface.w_data
     .mpeg_playback_avalon_mm_master_read_0_w_interface_w_addr  ( pb_w_addr), // .w_addr
     .mpeg_playback_avalon_mm_master_read_0_w_interface_w_en_pb0( pb0_w_en), // .w_en_pb0
     .mpeg_playback_avalon_mm_master_read_0_w_interface_w_en_pb1( pb1_w_en),  // .w_en_pb1
     .mpeg_recorder_mode_select_interface_0_mode_mode           ( mode),
     .mpeg_playback_avalon_mm_master_read_0_new_clk_clk         ( clk_playback), // mpeg_playback_avalon_mm_master_read_0_new_clk.clk
     .mpeg_irq_handler_0_led_test_signal_led_test_signal        ( led_test_signal), 
     .reset_bridge_0_in_reset_reset                             ( ~rst_n_gated),  // reset_bridge_0_in_reset.reset
     .mpeg_playback_avalon_mm_master_read_0_mpeg_sync_clk_cycle_count_mpeg_sync_clk_cycle_count ( mpeg_sync_clk_cycle_count)  // mpeg_playback_avalon_mm_master_read_0_mpeg_sync_clk_cycle_count.mpeg_sync_clk_cycle_count
     );
  
endmodule // mpeg_top_level

module debounce_switches 
  #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer DEBOUNCE_MS = 20
    )
  (
   input wire       clk,
   input wire       rst_n,

   input wire [3:0] sw_in,
   output reg [3:0] sw_out
   );

  // Number of clock cycles required for debounce period
  localparam integer COUNT_MAX = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

  // Counter width
  localparam integer COUNTER_WIDTH = $clog2(COUNT_MAX);

  reg [3:0]          sw_sync_0;
  reg [3:0]          sw_sync_1;

  reg [COUNTER_WIDTH-1:0] counter [3:0];

  integer                 i;

  // Synchronise switches to FPGA clock domain
  always_ff @ (posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      sw_sync_0 <= '0;
      sw_sync_1 <= '0;
    end
    else begin
      sw_sync_0 <= sw_in;
      sw_sync_1 <= sw_sync_0;
    end
  end

  // Debounce logic
  always_ff @ (posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      sw_out <= 4'b0000;
      for (i = 0; i < 4; i = i + 1) begin
        counter[i] <= 0;
      end
    end 
    else begin
      for (i = 0; i < 4; i = i + 1) begin
        // Input changed from stable output
        if (sw_sync_1[i] != sw_out[i]) begin

          // Count until debounce time expires
          if (counter[i] < COUNT_MAX - 1) begin
            counter[i] <= counter[i] + 1;
          end 
          else begin
            // Accept new stable state
            sw_out[i] <= sw_sync_1[i];
            counter[i] <= 0;
          end

        end 
        else begin
          // No change, reset counter
          counter[i] <= 0;
        end
      end
    end
  end

endmodule
`default_nettype wire
