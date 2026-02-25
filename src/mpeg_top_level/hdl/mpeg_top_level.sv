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
   output                              HPS_DDR3_WE_N
   );

  // PLL //
  wire sys_clk_100MHz;
  wire sys_clk_1MHz;
  wire pll_locked;
  pll pll0 
    (
     .refclk(ref_clk_50MHz),   //  refclk.clk
     .rst(~rst_n),	     //   reset.reset
     .outclk_0(sys_clk_100MHz), // outclk0.clk
     .outclk_1(sys_clk_1MHz), // outclk1.clk
     .locked(pll_locked) // locked.export
     );
  // //
  
  // Gate rst_n behind pll lock //
  wire rst_n_gated;
  assign rst_n_gated = rst_n & pll_locked;
  // // 
  
  // assign mpeg_clk_6MHz_out = mpeg_clk_6MHz;
  // assign mpeg_data_8_out = mpeg_data_8;
  // assign mpeg_sync_out = mpeg_sync;
  // assign mpeg_valid_out = mpeg_valid;

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

  // mpeg recorder //
  wire [31:0] r_data_32;
  wire [5:0]  r_addr;
  wire        r_en;
  wire        packet_done;
  
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
     .start(~start_sync),
     .stop(~stop_sync),
     .mpeg_clk_6MHz_out(mpeg_clk_6MHz_out),
     .mpeg_data_8_out(mpeg_data_8_out),
     .mpeg_sync_out(mpeg_sync_out),
     .mpeg_valid_out(mpeg_valid_out),
     .r_data_32(r_data_32),
     .r_addr(r_addr),
     .r_en(r_en),
     .packet_done_out(packet_done)
     );
  // //

  // LCD //
  wire [3:0] mode;
  mpeg_user_interface mpeg_user_interface0
    (
     .rst_n(rst_n_gated),
     .sys_clk_100MHz(sys_clk_100MHz),
     .sys_clk_1MHz(sys_clk_1MHz),
     .mode(mode),
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

  wire [31:0] hps_irq0;
  wire [31:0] hps_irq1;
  
  wire [7:0]  lw_dout;
      
  hps u0 
    (
     .clk_clk            ( sys_clk_100MHz),   //            clk.clk
     .lw_dout_export     ( lw_dout),          //        lw_dout.export
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
     .hps_0_f2h_irq1_irq ( hps_irq0),         // hps_0_f2h_irq1.irq
     .hps_0_f2h_irq0_irq ( hps_irq1),         // hps_0_f2h_irq0.irq
     .mpeg_recorder_avalon_mm_write_en_en                       ( mode[2]),
     .mpeg_recorder_avalon_mm_write_en_packet_done              ( packet_done),
     .mpeg_recorder_avalon_mm_master_write_0_r_interface_r_data ( r_data_32),
     .mpeg_recorder_avalon_mm_master_write_0_r_interface_r_addr ( r_addr),
     .mpeg_recorder_avalon_mm_master_write_0_r_interface_r_en   ( r_en)
     );
  
endmodule // mpeg_top_level
`default_nettype wire
