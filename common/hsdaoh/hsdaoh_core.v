// hsdaoh - High Speed Data Acquisition over HDMI
// Implementation of data output
// Copyright (C) 2024 by Steve Markgraf <steve@steve-m.de>
// License: MIT

module hsdaoh_core
(
	input wire rstn,
	output wire tmds_clk_n,
	output wire tmds_clk_p,
	output wire [2:0] tmds_d_n,
	output wire [2:0] tmds_d_p,
	input wire clk_pixel_x5,
	input wire clk_pixel,
	input wire fifo_empty,
	input wire fifo_aempty,
	output reg fifo_read_en,
	input wire [15:0] data_in
);

	parameter USE_CRC = 1;

	reg crc_enable = 1'b0;
	wire [15:0] crc_out;
	reg [15:0] last_line_crc;

	crc16_ccitt crc16_ccitt (
		.CLK(clk_pixel),
		.RSTn(rstn),
		.data_in({hdmi_data[15:8], hdmi_data[23:16]}),
		.enable(crc_enable),
		.clear(!crc_enable),
		.CRC(crc_out)
	);

	localparam [31:0] MAGIC = 32'hda7acab1;

	reg [23:0] hdmi_data = 24'h000000;
	reg [15:0] frame_cnt = 16'h0000;
	reg [15:0] idle_counter = 16'h0000;
	reg [15:0] line_word_cnt = 16'h00;
	reg [3:0] status_nibble = 4'h0;

	wire [11:0] cx;
	wire [10:0] cy;
	wire [11:0] frame_width;
	wire [10:0] frame_height;
	wire [11:0] screen_width;
	wire [10:0] screen_height;

always @(posedge clk_pixel) begin

	if (cy < screen_height) begin
		if (USE_CRC && (cx == 0))
			crc_enable <= 1'b1;

		if (USE_CRC && (cx == screen_width+1)) begin
			last_line_crc <= crc_out;
			crc_enable <= 1'b0;
		end

		if (cx == screen_width-1) begin
			// last word of line contains counter of words per line
			hdmi_data <= {status_nibble[3:0], line_word_cnt[11:0], 8'h00};

		end else if (USE_CRC && (cx == screen_width-2)) begin
			// second last word contains CRC
			hdmi_data <= {last_line_crc, 8'h00};

		end else if (cx < screen_width) begin
			if (fifo_read_en && !fifo_empty) begin
				// regular output of FIFO data
				hdmi_data <= {data_in[15:0], 8'h00};

				// increment line payload counter
				line_word_cnt <= line_word_cnt + 1'b1;
			end else begin
				// output idle counter
				hdmi_data <= {idle_counter[15:8], idle_counter[7:0], 8'h00};

				// increment idle counter
				idle_counter <= idle_counter + 1'b1;
			end
		end else
			line_word_cnt <= 16'h0000;

		// Enable reading before beginning of next line
		if ((cx == frame_width-1) && (cy != screen_height-1)) begin
			if (!fifo_empty)
				fifo_read_en = 1'b1;
		end

		// switch read off at end of line before sending the word counter
		// -2 because the last word is reserved (line_word_cnt and metadata)
		if (cx == screen_width-2-USE_CRC)
			fifo_read_en = 1'b0;
	end

	// switch read off during blanking
	if (cy > screen_height)
		fifo_read_en = 1'b0;

	// switch read off when FIFO has only one word remaining
	if (fifo_aempty)
		fifo_read_en = 1'b0;

	// increment the frame counter at the end of the frame
	if ((cx == frame_width-1) && (cy == frame_height-1)) begin
		frame_cnt <= frame_cnt + 1'b1;
		line_word_cnt <= 16'h0000;

		// start FIFO readout
		if (!fifo_empty)
			fifo_read_en = 1'b1;
	end

	if (cx == 0) begin
		case (cy)
			0  : status_nibble <= MAGIC[3:0];
			1  : status_nibble <= MAGIC[7:4];
			2  : status_nibble <= MAGIC[11:8];
			3  : status_nibble <= MAGIC[15:12];
			4  : status_nibble <= MAGIC[19:16];
			5  : status_nibble <= MAGIC[23:20];
			6  : status_nibble <= MAGIC[27:24];
			7  : status_nibble <= MAGIC[31:28];
			8  : status_nibble <= frame_cnt[3:0];
			9  : status_nibble <= frame_cnt[7:4];
			10 : status_nibble <= frame_cnt[11:8];
			11 : status_nibble <= frame_cnt[15:12];
			14 : status_nibble <= { 3'b000, USE_CRC };
			default : status_nibble <= 4'h0;
		endcase
	end
end

	wire tmds_clock;
	wire [2:0] tmds;

	hdmi #(
		.VIDEO_ID_CODE(16),
		.DVI_OUTPUT(0)
	) hdmi(
		.clk_pixel_x5(clk_pixel_x5),
		.clk_pixel(clk_pixel),
		.reset(!rstn),
		.rgb(hdmi_data),
		.tmds(tmds),
		.tmds_clock(tmds_clock),
		.cx(cx),
		.cy(cy),
		.frame_width(frame_width),
		.frame_height(frame_height),
		.screen_width(screen_width),
		.screen_height(screen_height)
	);
	ELVDS_OBUF tmds_bufds[3:0](
		.I({clk_pixel, tmds}),
		.O({tmds_clk_p, tmds_d_p}),
		.OB({tmds_clk_n, tmds_d_n})
	);

endmodule
