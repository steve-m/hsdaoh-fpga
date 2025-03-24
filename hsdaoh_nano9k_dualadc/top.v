// hsdaoh - High Speed Data Acquisition over HDMI
// Dual 12 bit ADC top design for Tang Nano 9K
// Copyright (C) 2024-25 by Steve Markgraf <steve@steve-m.de>
// License: MIT

module top (
	sys_clk,
	sys_resetn,
	tmds_clk_n,
	tmds_clk_p,
	tmds_d_n,
	tmds_d_p,
	adc0_data,
	adc1_data,
	adc_clkout
);
	input sys_clk;
	input sys_resetn;
	output wire tmds_clk_n;
	output wire tmds_clk_p;
	output wire [2:0] tmds_d_n;
	output wire [2:0] tmds_d_p;

	input wire [11:0] adc0_data;
	input wire [11:0] adc1_data;
    output wire adc_clkout;

	wire [2:0] tmds;
	wire clk_pixel;
	wire clk_pixel_x5;
	wire hdmi_pll_lock;

    wire data_pll_out;
	wire clk_data;
	wire data_pll_lock;

    assign adc_clkout = clk_data;

	localparam HDMI_PLL_IDIV  = 3;
	localparam HDMI_PLL_FBDIV = 46;
	localparam HDMI_PLL_ODIV  = 2;

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

    // 120 MHz
	localparam DATA_PLL_IDIV  = 8;
	localparam DATA_PLL_FBDIV = 39;
	localparam DATA_PLL_ODIV  = 8;

    // 120 MHz / 3 = 40 MHz
    clk_div3 clkdiv (.clk(data_pll_out),
                    .reset (!hdmi_pll_lock),
                    .clk_out(clk_data));

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
		.CLKOUT   (data_pll_out),
		.LOCK	 (data_pll_lock),
		.CLKOUTP  (),
		.CLKOUTD  (),
		.CLKOUTD3 ()
	);

	reg [23:0] fifo_in;

	wire write_enable;

	wire [23:0] fifo_out;
	wire fifo_empty;
	wire fifo_aempty;
	wire Full_o;

	wire FifoHalfFull;
	wire FifoFull;

	wire fifo_rd_en_i;

	async_fifo #(
		.DSIZE(24),
		.ASIZE($clog2(8192)),	// 3 + (1982 * 4) = 7931 => at least 8K entries to buffer 4 lines during VSYNC
		.FALLTHROUGH("FALSE")
	) fifo (
		.wclk(clk_data),
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
        fifo_in <= {adc0_data[11:0], adc1_data[11:0]};
	end

endmodule
