// hsdaoh - High Speed Data Acquisition over HDMI
// Test top design for Tang Nano 9K
// Copyright (C) 2024 by Steve Markgraf <steve@steve-m.de>
// License: MIT

module top (
	sys_clk,
	sys_resetn,
	tmds_clk_n,
	tmds_clk_p,
	tmds_d_n,
	tmds_d_p,
	rf_in_n,
	rf_in_p
);
	input sys_clk;
	input sys_resetn;
	output wire tmds_clk_n;
	output wire tmds_clk_p;
	output wire [2:0] tmds_d_n;
	output wire [2:0] tmds_d_p;
	input wire rf_in_n;
	input wire rf_in_p;

	wire [2:0] tmds;
	wire clk_pixel;
	wire clk_pixel_x5;
	wire hdmi_pll_lock;

	wire clk_data;
	wire clk_data_div;
	wire rf_in_1bit;
	wire rf_in_1bit_q0;
	wire rf_in_1bit_q1;
	wire data_pll_lock;

	// https://juj.github.io/gowin_fpga_code_generators/pll_calculator.html
	localparam HDMI_PLL_IDIV  = 0;
	localparam HDMI_PLL_FBDIV = 7;
	localparam HDMI_PLL_ODIV  = 4;

	// PLL for HDMI clock
	rPLL #(
		.FCLKIN	(27),
		.IDIV_SEL  (HDMI_PLL_IDIV),
		.FBDIV_SEL (HDMI_PLL_FBDIV),
		.ODIV_SEL  (HDMI_PLL_ODIV),
		.DEVICE	("GW1NR-9C")
	) hdmi_pll (
		.CLKIN(sys_clk),
		.CLKFB(1'b0),
		.RESET(1'b0),
		.RESET_P(1'b0),
		.FBDSEL(6'b0),
		.IDSEL(6'b0),
		.ODSEL(6'b0),
		.DUTYDA(4'b0),
		.PSDA(4'b0),
		.FDLY(4'b0),
		.CLKOUT(clk_pixel_x5),
		.LOCK(hdmi_pll_lock),
		.CLKOUTP(),
		.CLKOUTD(),
		.CLKOUTD3()
	);

	CLKDIV #(
		.DIV_MODE(5),
		.GSREN("false")
	) div_5 (
		.CLKOUT(clk_pixel),
		.HCLKIN(clk_pixel_x5),
		.RESETN(hdmi_pll_lock),
		.CALIB(1'b0)
	);

	// 144MHz LVDS sampling clock
	localparam DATA_PLL_IDIV  = 2;
	localparam DATA_PLL_FBDIV = 15;
	localparam DATA_PLL_ODIV  = 8;

	// PLL for data clock
	rPLL #(
		.FCLKIN	(27),
		.IDIV_SEL  (DATA_PLL_IDIV),
		.FBDIV_SEL (DATA_PLL_FBDIV),
		.ODIV_SEL  (DATA_PLL_ODIV),
		.DEVICE	("GW1NR-9C")
	) data_pll (
		.CLKIN	(sys_clk),
		.CLKFB	(1'b0),
		.RESET	(rst),
		.RESET_P  (1'b0),
		.FBDSEL   (6'b0),
		.IDSEL	(6'b0),
		.ODSEL	(6'b0),
		.DUTYDA   (4'b0),
		.PSDA	 (4'b0),
		.FDLY	 (4'b0),
		.CLKOUT   (clk_data),
		.LOCK	 (data_pll_lock),
		.CLKOUTP  (),
		.CLKOUTD  (),
		.CLKOUTD3 ()
	);

	CLKDIV #(
		.DIV_MODE(4),
		.GSREN("false")
	) div_4 (
		.CLKOUT(clk_data_div),
		.HCLKIN(clk_data),
		.RESETN(data_pll_lock),
		.CALIB(1'b0)
	);

	reg [1:0] counter = 2'h0;
	reg [4:0] accumulator = 2'h0;

	reg [15:0] fifo_in;

	wire write_enable;

	wire [15:0] fifo_out;
	wire fifo_empty;
	wire fifo_aempty;
	wire Full_o;

	wire FifoHalfFull;
	wire FifoFull;

	wire fifo_rd_en_i;
	async_fifo #(
		.DSIZE(16),
		.ASIZE($clog2(8192*2)),	// 3 + (1982 * 4) = 7931 => at least 8K entries to buffer 4 lines during VSYNC
		.FALLTHROUGH("FALSE")
	) fifo (
		.wclk(clk_data_div),
		.wrst_n(hdmi_pll_lock),
		.winc(write_enable),
		.wdata(fifo_in),
		.wfull(FifoFull),
		.awfull(FifoHalfFull), //fixme
		.rclk(clk_pixel),
		.rrst_n(hdmi_pll_lock),
		.rinc(fifo_rd_en_i),
		.rdata(fifo_out),
		.rempty(fifo_empty),
		.arempty(fifo_aempty)
	);

/*
	FIFO_HS_Top fifo(
		.Data(fifo_in), //input [0:0] Data
		.WrClk(clk_data_div), //input WrClk
		.RdClk(clk_pixel), //input RdClk
		.WrEn(write_enable), //input WrEn
		.RdEn(fifo_rd_en_i), //input RdEn
		.Almost_Empty(fifo_aempty), //output Almost_Empty
		.Q(fifo_out), //output [0:0] Q
		.Empty(fifo_empty), //output Empty
		.Full(FifoFull) //output Full
	);
*/


	hsdaoh_core hsdaoh (
		.rstn(hdmi_pll_lock),
		.tmds_clk_n(tmds_clk_n),
		.tmds_clk_p(tmds_clk_p),
		.tmds_d_n(tmds_d_n),
		.tmds_d_p(tmds_d_p),
		.clk_pixel_x5(clk_pixel_x5),
		.clk_pixel(clk_pixel),
		.fifo_empty(fifo_empty),
		.fifo_aempty(fifo_aempty),
		.fifo_read_en(fifo_rd_en_i),
		.data_in(fifo_out)
	);
	
	assign write_enable = 1'b1;

	always @(posedge clk_data) begin
		counter <= counter + 1'b1;
		if (counter == 0) begin
			accumulator <= rf_in_1bit_q0 + rf_in_1bit_q1;
			fifo_in <= accumulator;
		end else begin
			accumulator <= accumulator + rf_in_1bit_q0 + rf_in_1bit_q1;
		end
	end
	
	IDDR rf_ddr (
		.Q0(rf_in_1bit_q0),
		.Q1(rf_in_1bit_q1),
		.D(rf_in_1bit),
		.CLK(clk_data)
	);
	TLVDS_IBUF rf_in (
		.I(rf_in_n),
		.IB(rf_in_p),
		.O(rf_in_1bit)
	);

endmodule
