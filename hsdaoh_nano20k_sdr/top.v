// hsdaoh - High Speed Data Acquisition over HDMI
// hsdaohSDR top design for Tang Nano 20K
// Copyright (C) 2024 by Steve Markgraf <steve@steve-m.de>
// License: MIT

module top (
	sys_clk,
	tmds_clk_n,
	tmds_clk_p,
	tmds_d_n,
	tmds_d_p,
	adc0_data,
	adc1_data,
	adc_clkout,
	uart_rx,
	uart_tx,
	i2c_scl,
	i2c_sda,
	pa_en,
	lcd_bl,
	bl616_boot
);
	input sys_clk;
	output wire tmds_clk_n;
	output wire tmds_clk_p;
	output wire [2:0] tmds_d_n;
	output wire [2:0] tmds_d_p;

	input wire [9:0] adc0_data;
	input wire [9:0] adc1_data;
	output wire adc_clkout;

	input wire uart_rx;
	output wire uart_tx;

	inout wire i2c_scl;
	inout wire i2c_sda;

	output wire pa_en;
	output wire lcd_bl;
	output wire bl616_boot;

	wire [2:0] tmds;
	wire clk_pixel;
	wire clk_pixel_x5;
	wire hdmi_pll_lock;

	wire clk_data;
	wire data_pll_lock;

	assign pa_en = 1'b0;
	assign lcd_bl = 1'b0;
	assign bl616_boot = 1'b1;

	assign adc_clkout = clk_data;

	// 477 MHz, maximum that works with the nano 20K
	// 477/5 = 95.4 MHz
	localparam HDMI_PLL_IDIV  = 2;
	localparam HDMI_PLL_FBDIV = 52;
	localparam HDMI_PLL_ODIV  = 2;

	// PLL for HDMI clock
	rPLL #(
		.FCLKIN	(27),
		.IDIV_SEL  (HDMI_PLL_IDIV),
		.FBDIV_SEL (HDMI_PLL_FBDIV),
		.ODIV_SEL  (HDMI_PLL_ODIV),
		.DEVICE	("GW2AR-18C")
	) hdmi_pll (
		.CLKIN	(sys_clk),
		.CLKFB	(1'b0),
		.RESET	(1'b0),
		.RESET_P  (1'b0),
		.FBDSEL   (6'b0),
		.IDSEL	(6'b0),
		.ODSEL	(6'b0),
		.DUTYDA   (4'b0),
		.PSDA	 (4'b0),
		.FDLY	 (4'b0),
		.CLKOUT   (clk_pixel_x5),
		.LOCK	 (hdmi_pll_lock),
		.CLKOUTP  (),
		.CLKOUTD  (),
		.CLKOUTD3 ()
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

	// 91.8 MHz clock for data (ignored, using dynamic settings)
	localparam DATA_PLL_IDIV  = 6;
	localparam DATA_PLL_FBDIV = 18;
	localparam DATA_PLL_ODIV  = 16;

	wire data_pll_reset;
	wire tenbit_enable;

	assign data_pll_reset = settings[18];
	assign tenbit_enable = settings[19];

	// PLL for data clock
	rPLL #(
		.FCLKIN	(27),
		.IDIV_SEL  (DATA_PLL_IDIV),
		.FBDIV_SEL (DATA_PLL_FBDIV),
		.ODIV_SEL  (DATA_PLL_ODIV),
		.DYN_IDIV_SEL("true"),
		.DYN_FBDIV_SEL("true"),
		.DYN_ODIV_SEL("true"),
		.DEVICE	("GW2AR-18C")
	) data_pll (
		.CLKIN(sys_clk),
		.CLKFB(1'b0),
		.RESET(data_pll_reset),
		.RESET_P(1'b0),
		.FBDSEL(settings[5:0]),
		.IDSEL(settings[11:6]),
		.ODSEL(settings[17:12]),
		.DUTYDA(4'b0),
		.PSDA(4'b0),
		.FDLY(4'b0),
		.CLKOUT(clk_data),
		.LOCK(data_pll_lock),
		.CLKOUTP(),
		.CLKOUTD(),
		.CLKOUTD3()
	);

	reg [19:0] counter = 16'h0000;

	reg [19:0] fifo_in;

	wire write_enable;

	wire [19:0] fifo_out;
	wire fifo_empty;
	wire fifo_aempty;

	wire fifo_full;
	wire fifo_afull;

	wire fifo_read_en;
	async_fifo #(
		.DSIZE(20),
		.ASIZE($clog2(16384)),
		.FALLTHROUGH("FALSE")
	) fifo (
		.wclk(clk_data),
		.wrst_n(hdmi_pll_lock),
		.winc(write_enable),
		.wdata(fifo_in),
		.wfull(fifo_full),
		.awfull(fifo_afull),
		.rclk(clk_pixel),
		.rrst_n(hdmi_pll_lock),
		.rinc(fifo_read_en),
		.rdata(fifo_out),
		.rempty(fifo_empty),
		.arempty(fifo_aempty)
	);

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
		.fifo_read_en(fifo_read_en),
		.data_in(fifo_out),
		.tenbit_enable_in(tenbit_enable)
	);

	wire [31:0] settings;

	uart_i2c_bridge #(
	) uart_i2c_bridge (
		.clk(sys_clk),
		.rst_n(1'b1),//pll_lock),
		.uart_rx(uart_rx),
		.uart_tx(uart_tx),
		.i2c_sda(i2c_sda),
		.i2c_scl(i2c_scl),
		.settings(settings)
	);

	assign write_enable = 1'b1;

	always @(posedge clk_data) begin
		fifo_in <= {adc0_data[9:0], adc1_data[9:0]};
		counter <= counter + 1'b1;
	end

endmodule
