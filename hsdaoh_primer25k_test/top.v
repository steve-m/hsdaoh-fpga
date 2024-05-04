// hsdaoh - High Speed Data Acquisition over HDMI
// Test top design for Tang Primer 25K
// Copyright (C) 2024 by Steve Markgraf <steve@steve-m.de>
// License: MIT

module top (
	sys_clk,
	sys_resetn,
	tmds_clk_n,
	tmds_clk_p,
	tmds_d_n,
	tmds_d_p
);
	input sys_clk;
	input sys_resetn;
	output wire tmds_clk_n;
	output wire tmds_clk_p;
	output wire [2:0] tmds_d_n;
	output wire [2:0] tmds_d_p;

	wire [2:0] tmds;
	wire clk_pixel;
	wire clk_pixel_x5;
	wire pll_lock;

	wire clk_data;

	// 475 MHz, maximum that works with the primer 25K
	// 475/5 = 95 MHz
	// Data PLL output is 89.0625 MHz

	PLLA #(
		.FCLKIN			("50"),
		.IDIV_SEL		(2),
		.FBDIV_SEL		(1),
		.CLKFB_SEL		("INTERNAL"),
		.ODIV0_SEL		(3),
		.ODIV0_FRAC_SEL		(0),
		.ODIV1_SEL		(16),
		.ODIV2_SEL		(8),
		.ODIV3_SEL		(8),
		.ODIV4_SEL		(8),
		.ODIV5_SEL		(8),
		.ODIV6_SEL		(8),
		.MDIV_SEL		(57),
		.MDIV_FRAC_SEL		(0),
		.CLKOUT0_EN		("TRUE"),
		.CLKOUT1_EN		("TRUE"),
		.CLKOUT2_EN		("FALSE"),
		.CLKOUT3_EN		("FALSE"),
		.CLKOUT4_EN		("FALSE"),
		.CLKOUT5_EN		("FALSE"),
		.CLKOUT6_EN		("FALSE"),
		.CLKOUT0_DT_DIR		(1'b1),
		.CLKOUT0_DT_DIR		(1'b1),
		.CLKOUT1_DT_DIR		(1'b1),
		.CLKOUT2_DT_DIR		(1'b1),
		.CLKOUT3_DT_DIR		(1'b1),
		.CLK0_IN_SEL		(1'b0),
		.CLK0_OUT_SEL		(1'b0),
		.CLK1_IN_SEL		(1'b0),
		.CLK1_OUT_SEL		(1'b0),
		.CLK2_IN_SEL		(1'b0),
		.CLK2_OUT_SEL		(1'b0),
		.CLK3_IN_SEL		(1'b0),
		.CLK3_OUT_SEL		(1'b0),
		.CLK4_IN_SEL		(2'b00),
		.CLK4_OUT_SEL		(1'b0),
		.CLK5_IN_SEL		(1'b0),
		.CLK5_OUT_SEL		(1'b0),
		.CLK6_IN_SEL		(1'b0),
		.CLK6_OUT_SEL		(1'b0),
		.CLKOUT0_PE_COARSE	(0),
		.CLKOUT0_PE_FINE	(0),
		.CLKOUT1_PE_COARSE	(0),
		.CLKOUT1_PE_FINE	(0),
		.CLKOUT2_PE_COARSE	(0),
		.CLKOUT2_PE_FINE	(0),
		.CLKOUT3_PE_COARSE	(0),
		.CLKOUT3_PE_FINE	(0),
		.CLKOUT4_PE_COARSE	(0),
		.CLKOUT4_PE_FINE	(0),
		.CLKOUT5_PE_COARSE	(0),
		.CLKOUT5_PE_FINE	(0),
		.CLKOUT6_PE_COARSE	(0),
		.CLKOUT6_PE_FINE	(0),
		.DE0_EN			("FALSE"),
		.DE1_EN			("FALSE"),
		.DE2_EN			("FALSE"),
		.DE3_EN			("FALSE"),
		.DE4_EN			("FALSE"),
		.DE5_EN			("FALSE"),
		.DE6_EN			("FALSE"),
		.DYN_DPA_EN		("FALSE"),
		.DYN_PE0_SEL		("FALSE"),
		.DYN_PE1_SEL		("FALSE"),
		.DYN_PE2_SEL		("FALSE"),
		.DYN_PE3_SEL		("FALSE"),
		.DYN_PE4_SEL		("FALSE"),
		.DYN_PE5_SEL		("FALSE"),
		.DYN_PE6_SEL		("FALSE"),
		.RESET_I_EN		("FALSE"),
		.RESET_O_EN		("FALSE"),
		.ICP_SEL		(6'bXXXXXX),
		.LPF_RES		(3'bXXX),
		.LPF_CAP		(2'b00),
		.SSC_EN			("FALSE"),
		.CLKOUT0_DT_STEP	(0),
		.CLKOUT1_DT_STEP	(0),
		.CLKOUT2_DT_STEP	(0),
		.CLKOUT3_DT_STEP	(0)
	) pll (
		.LOCK(pll_lock),
		.CLKOUT0(clk_pixel_x5),
		.CLKOUT1(clk_data),
		.CLKIN(sys_clk),
		.CLKFB(1'b0),
		.RESET(1'b0),
		.PLLPWD(1'b0),
		.RESET_I(1'b0),
		.RESET_O(1'b0),
		.PSSEL(3'b0),
		.PSDIR(1'b0),
		.PSPULSE(1'b0),
		.SSCPOL(1'b0),
		.SSCON(1'b0),
		.SSCMDSEL(7'b0),
		.SSCMDSEL_FRAC(3'b0),
		.MDCLK(1'b0),
		.MDOPC(2'b0),
		.MDAINC(1'b0),
		.MDWDI(8'b0)
	);

	CLKDIV #(
		.DIV_MODE(5)
	) div_5 (
		.CLKOUT(clk_pixel),
		.HCLKIN(clk_pixel_x5),
		.RESETN(1'b1),
		.CALIB(1'b0)
	);

	reg [15:0] counter = 16'h0000;
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
		.ASIZE($clog2(16384)),	// 3 + (1982 * 4) = 7931 => at least 8K entries to buffer 4 lines during VSYNC
		.FALLTHROUGH("FALSE")
	) fifo (
		.wclk(clk_data),
		.wrst_n(pll_lock),
		.winc(write_enable),
		.wdata(fifo_in),
		.wfull(FifoFull),
		.awfull(FifoHalfFull),
		.rclk(clk_pixel),
		.rrst_n(pll_lock),
		.rinc(fifo_rd_en_i),
		.rdata(fifo_out),
		.rempty(fifo_empty),
		.arempty(fifo_aempty)
	);

	hsdaoh_core hsdaoh (
		.rstn(pll_lock),
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
		fifo_in <= counter[15:0];
		counter <= counter + 1'b1;
	end
endmodule
