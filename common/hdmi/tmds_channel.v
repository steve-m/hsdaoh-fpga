// Pipelined TMDS encoder
// based on https://github.com/juj/gowin_flipflop_drainer/blob/main/src/hdmi.v (Public Domain)
//
// TERC4 + Video/Data Guard bands based on https://github.com/hdl-util/hdmi/
// by Sameer Puri
//
// adapted for hsdaoh by Steve Markgraf <steve@steve-m.de>
//
// Dual-licensed under Apache License 2.0 and MIT License.

// tmds_encoder performs Transition-minimized differential signaling (TMDS) encoding of
// 8-bits of pixel data and 2-bits of control data to a 10-bit TMDS encoded format.
module tmds_channel(
	input clk_pixel,              // HDMI pixel clock
	input reset,                  // reset (active high)
	input [7:0] video_data,       // Input 8-bit color
	input [3:0] data_island_data, // HDMI data island data
	input [1:0] control_data,     // control data (vsync and hsync)
	input [2:0] mode,             // Mode select (0 = control, 1 = video, 2 = video guard, 3 = island, 4 = island guard)
	output reg [9:0] tmds         // encoded 10-bit TMDS data
);

	// TMDS Channel number.
	// There are only 3 possible channel numbers in HDMI 1.4a: 0, 1, 2.
	parameter [1:0] CN = 0;

	// Intermediate pipelined variables: the number after each reg specifies the clock cycle of the pipeline the values are accessed at.

	// Reset
	reg rst0;
	// Unencoded input data
	reg [7:0] dat0, dat1, dat2, dat3, dat4, dat5, dat6, dat7 ;
	// Control signal (hsync and vsync)
	reg [1:0] ctl0, ctl1, ctl2, ctl3, ctl4, ctl5, ctl6, ctl7, ctl8, ctl9, ctl10, ctl11, ctl12, ctl13, ctl14, ctl15, ctl16, ctl17, ctl18, ctl19;
	// Output mode
	reg [2:0] mode0, mode1, mode2, mode3, mode4, mode5, mode6, mode7, mode8, mode9, mode10, mode11, mode12, mode13, mode14, mode15, mode16, mode17, mode18, mode19;
	// Data island data
	reg [3:0] di_dat0, di_dat1, di_dat2, di_dat3, di_dat4, di_dat5, di_dat6, di_dat7, di_dat8, di_dat9, di_dat10, di_dat11, di_dat12, di_dat13, di_dat14, di_dat15, di_dat16, di_dat17, di_dat18, di_dat19;
	// Display enable signal
	reg den0, den1, den2, den3, den4, den5, den6, den7, den8, den9, den10, den11, den12, den13, den14, den15, den16, den17, not_den18;
	// Parity count of input data
	reg [4:0] par1, par2, par3, par4, par5, par6, par7, par8;
	// Parity bit of input data (if set, input had >= 4 bits set).
	reg par9, par10, par11, par12, par13, par14, par15, par16, par17, par18;
	// Intermediate encoded stage of the input vector.
	reg [7:0] enc3, enc4, enc5, enc6, enc7, enc8, enc9, enc10, enc11, enc12, enc13, enc14, enc15, enc16, enc17, enc18;
	// Count the number of ones in the intermediate encoded data
	reg signed [3:0] eon10, eon11, eon13, eon14, eon15, eon16, eon17, eon18;
	// Is Encoded ONes even?
	reg eve18;
	// Temp values for accumulating the count of ones in the encoded vector.
	reg [3:0] tpa10, tpa11, tpb11;
	reg [2:0] tpa12, tpb12;
	// Pipelined values for updating the bias count.
	reg signed [3:0] inv18, shr18, shl18;
	// Pipelined values for the output TMDS data.
	reg [9:0] tmds_blank18, tmds_even18, tmds_pos18, tmds_neg18;
	// 'bias' stores the running TMDS ones vs zeros balance count. If > 0, we've sent more ones to the bus,
	// if < 0, we've sent more zeroes than ones, if == 0, we are at equal balance.
	reg signed [3:0] bias;

	reg [9:0] tmds_video;

	// See Section 5.4.3
	reg [9:0] terc4_coding;
	always @(*)
	begin
		case (di_dat19)
			4'b0000: terc4_coding = 10'b1010011100;
			4'b0001: terc4_coding = 10'b1001100011;
			4'b0010: terc4_coding = 10'b1011100100;
			4'b0011: terc4_coding = 10'b1011100010;
			4'b0100: terc4_coding = 10'b0101110001;
			4'b0101: terc4_coding = 10'b0100011110;
			4'b0110: terc4_coding = 10'b0110001110;
			4'b0111: terc4_coding = 10'b0100111100;
			4'b1000: terc4_coding = 10'b1011001100;
			4'b1001: terc4_coding = 10'b0100111001;
			4'b1010: terc4_coding = 10'b0110011100;
			4'b1011: terc4_coding = 10'b1011000110;
			4'b1100: terc4_coding = 10'b1010001110;
			4'b1101: terc4_coding = 10'b1001110001;
			4'b1110: terc4_coding = 10'b0101100011;
			4'b1111: terc4_coding = 10'b1011000011;
		endcase
	end

	// See Section 5.2.2.1
	wire [9:0] video_guard_band;
	generate
		if ((CN == 0) || (CN == 2)) begin : genblk1
			assign video_guard_band = 10'b1011001100;
		end
		else begin : genblk1
			assign video_guard_band = 10'b0100110011;
		end
	endgenerate

	// See Section 5.2.3.3
	wire [9:0] data_guard_band;
	generate
		if ((CN == 1) || (CN == 2)) begin : genblk2
			assign data_guard_band = 10'b0100110011;
		end
		else begin : genblk2
			assign data_guard_band = (ctl19 == 2'b00 ? 10'b1010001110 : (ctl19 == 2'b01 ? 10'b1001110001 : (ctl19 == 2'b10 ? 10'b0101100011 : 10'b1011000011)));
		end
	endgenerate

	always @(posedge clk_pixel) begin
		// Clock 0: register inputs
		rst0 <= reset;
		dat0 <= video_data;
		di_dat0 <= data_island_data;
		ctl0 <= control_data;
		den0 <= (mode == 1); // display enable (high=pixel data active. low=display is in blanking area)
		mode0 <= mode;

		// Clock 1: handle reset early by folding it into the other fields
		dat1 <= dat0;
		ctl1 <= rst0 ? 2'b0 : ctl0;
		den1 <= rst0 ? 1'b0 : den0;
		mode1 <= rst0 ? 3'b0 : mode0;

		// Clock 2: sanitize image data to zero if inside display blank (or reset)
		dat2 <= den1 ? dat1 : 8'b0;
		ctl2 <= ctl1;
		den2 <= den1;
		mode2 <= mode1;

		// Clocks 3-7: Pipeline 'dat' for the duration of the parity encoding below.
		dat3 <= dat2;
		dat4 <= dat3;
		dat5 <= dat4;
		dat6 <= dat5;
		dat7 <= dat6;

		// Clocks 1-8: Calculate parity, i.e. whether the input vector 'dat' has more
		//             ones in it than zeros. If it has 4 zeros and 4 ones, use ~dat[0]
		//             as a tie. To do that, start with constant vector 00001, and for
		//             each bit set in input 'dat', shift 'par' left by one place, filling
		//             in ones. At the end par[4] will specifies whether there were more
		//             ones than zeroes.
		par1 <= 5'b00001;
		par2 <= dat1[1] ? {par1[3:0], 1'b1} : par1; // = 000ab (a,b=unknown, 000=zeroes)
		par3 <= dat2[2] ? {par2[3:0], 1'b1} : par2; // = 00abc
		par4 <= dat3[3] ? {par3[3:0], 1'b1} : par3; // = 0abcd
		par5 <= dat4[4] ? {par4[3:0], 1'b1} : par4; // = abcdx (x=don't care, rely on optimizer to clear these away)
		par6 <= dat5[5] ? {par5[3:0], 1'b1} : par5; // = bcdxx
		par7 <= dat6[6] ? {par6[3:0], 1'b1} : par6; // = cdxxx
		par8 <= dat7[7] ? {par7[3:0], 1'b1} : par7; // = dxxxx

		// Clocks 9-18: No further calculation needed for parity. Keep pipelining it forward
		//              in a single bit vector.
		par9 <= par8[4]; // At the end of computation par[4] records the parity.
		par10 <= par9;
		par11 <= par10;
		par12 <= par11;
		par13 <= par12;
		par14 <= par13;
		par15 <= par14;
		par16 <= par15;
		par17 <= par16;
		par18 <= par17;

		// Clocks 3-18: No more changes needed to the Display Enable signal, flow it through the pipeline
		den3 <= den2;
		den4 <= den3;
		den5 <= den4;
		den6 <= den5;
		den7 <= den6;
		den8 <= den7;
		den9 <= den8;
		den10 <= den9;
		den11 <= den10;
		den12 <= den11;
		den13 <= den12;
		den14 <= den13;
		den15 <= den14;
		den16 <= den15;
		den17 <= den16;
		not_den18 <= ~den17;

		mode3 <= mode2;
		mode4 <= mode3;
		mode5 <= mode4;
		mode6 <= mode5;
		mode7 <= mode6;
		mode8 <= mode7;
		mode9 <= mode8;
		mode10 <= mode9;
		mode11 <= mode10;
		mode12 <= mode11;
		mode13 <= mode12;
		mode14 <= mode13;
		mode15 <= mode14;
		mode16 <= mode15;
		mode17 <= mode16;
		mode18 <= mode17;
		mode19 <= mode18;

		di_dat1 <= di_dat0;
		di_dat2 <= di_dat1;
		di_dat3 <= di_dat2;
		di_dat4 <= di_dat3;
		di_dat5 <= di_dat4;
		di_dat6 <= di_dat5;
		di_dat7 <= di_dat6;
		di_dat8 <= di_dat7;
		di_dat9 <= di_dat8;
		di_dat10 <= di_dat9;
		di_dat11 <= di_dat10;
		di_dat12 <= di_dat11;
		di_dat13 <= di_dat12;
		di_dat14 <= di_dat13;
		di_dat15 <= di_dat14;
		di_dat16 <= di_dat15;
		di_dat17 <= di_dat16;
		di_dat18 <= di_dat17;
		di_dat19 <= di_dat18;

		// Clocks 3-18: Pipeline ctrl data (hsync & vsync), no changes needed.
		ctl3 <= ctl2;
		ctl4 <= ctl3;
		ctl5 <= ctl4;
		ctl6 <= ctl5;
		ctl7 <= ctl6;
		ctl8 <= ctl7;
		ctl9 <= ctl8;
		ctl10 <= ctl9;
		ctl11 <= ctl10;
		ctl12 <= ctl11;
		ctl13 <= ctl12;
		ctl14 <= ctl13;
		ctl15 <= ctl14;
		ctl16 <= ctl15;
		ctl17 <= ctl16;
		ctl18 <= ctl17;
		ctl19 <= ctl18;

		// Clocks 3-9: perform intermediate encoded vector 'enc' of the input 'data' field. At the
		//             end of the encoding, the DVI spec says the encoded vector should look like
		//             follows:
		// enc <= { parity ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7],
		//                   data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6],
		//          parity ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5],
		//                   data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4],
		//          parity ^ data[0] ^ data[1] ^ data[2] ^ data[3],
		//                   data[0] ^ data[1] ^ data[2],
		//          parity ^ data[0] ^ data[1],
		//                   data[0] };
		//
		// Calculate it across a few clock cycles to avoid high complexity per clock. (ignore parity first)
		// Bit lanes after each clock cycle:
		//                [7]     [6]    [5]   [4]  [3] [2] [1] [0]
		// Clock 2:        7       6      5     4    3   2   1   0
		// Clock 3:       76      65     54    43   32  21  10   0
		// Clock 4:     7654    6543   5432  4321 3210 210  10   0
		// Clock 5: 76543210 6543210 543210 43210 3210 210  10   0

		enc3 <= {dat2[7:1]^dat2[6:0], dat2[  0]};
		enc4 <= {enc3[7:2]^enc3[5:0], enc3[1:0]};
		enc5 <= {enc4[7:4]^enc4[3:0], enc4[3:0]};
		enc6 <= enc5;
		enc7 <= enc6;
		enc8 <= enc7;

		// Clock 9: Meanwhile, parity computation has completed, so apply the final parity XOR to the
		//          intermediate encoded vector.
		enc9 <= enc8 ^ {4{par8[4], 1'b0}};
		enc10 <= enc9;
		enc11 <= enc10;
		enc12 <= enc11;
		enc13 <= enc12;
		enc14 <= enc13;
		enc15 <= enc14;
		enc16 <= enc15;
		enc17 <= enc16;
		enc18 <= enc17;

		// Clocks 10-17: calculate 'eon' (Encoded ONes vs zeros): a signed count that specifies whether
		//               vector 'enc' has more ones or zeroes in it.
		tpa10 <= enc9[3:0] ^ enc9[7:4]; // Fold the 8 bit enc vector into two 4-bit halves, and half-
		tpa11 <= tpa10;                 // Then calculate the number of ones in them in parallel
		tpb11 <= enc10[3:0] & enc10[7:4];//tpb10;
		tpa12 <= tpa11[3] + tpa11[2] + tpa11[1] + tpa11[0]; // Then calculate the number of ones in them in parallel
		tpb12 <= tpb11[3] + tpb11[2] + tpb11[1] + tpb11[0]; // for SV $countones(tpb11) can be used
		eon13 <= tpa12 + {tpb12, 1'b0}; // Then use a 3-bit + 4-bit addition to bring the full count.
		eon14 <= eon13 - 3'd4;          // And make the result signed.
		eon15 <= eon14;
		eon16 <= eon15;
		eon17 <= eon16;
		eon18 <= eon17;

		// 'eon17' is a count of balance of ones vs zeros in input encoded vector 'enc':
		//        #ones: 8 7 6 5 4  3  2  1  0
		// #ones-#zeros: 8 6 4 2 0 -2 -4 -6 -8
		// value of eon: 4 3 2 1 0 -1 -2 -3 -4

		// Pipeline a few finishing touches:
		eve18 <= eon17 == 0;                      // is the balance equal (zero)?
		inv18 <= par17 ? -eon17     : eon17;      // invert balance count based on parity.
		shr18 <= par17 ? eon17      : eon17-1'b1; // right shift balance count based on parity.
		shl18 <= par17 ? eon17-1'b1 : eon17;      // left shift balance count based on parity.
		tmds_blank18 <= {~ctl17[1], 9'b101010100} ^ {10{ctl17[0]}};
		tmds_even18 <= {par17, ~par17, {8{par17}} ^ enc17};
		tmds_pos18 <= {1'b1, ~par17, 8'hff ^ enc17};
		tmds_neg18 <= {1'b0, ~par17,         enc17};

		// Clocks 14-17 above:
		// These are "empty" filler clock stages that contain no computations on any of the variables,
		// but they only perform direct passthrough of the values that have been computed so far.
		// Gowin IDE Analyzer reports that this improves max. timing performance.

		// Clock 18: finally output the TMDS encoded value, and update bias value
		if (not_den18) begin // In display blank?
			tmds_video <= tmds_blank18;          // Output control words for hsync and vsync
			bias <= 0;                           // Bias resets to zero in blank
		end else if (eve18 || bias == 0) begin       // If current bias is even, or encoded balance is even..
			tmds_video <= tmds_even18;           // .. use a specific 'even' state TMDS formula.
			bias <= bias + inv18;                // This does not seem to be strictly necessary, you can try removing this else block for tiny bit more performance.
		end else if (bias[3] == eon18[3]) begin      // Otherwise, noneven bias and balance, so use the main TMDS encoding formula
			tmds_video <= tmds_pos18;
			bias <= bias - shr18;                // and update running bias of ones vs zeros sent.
		end else begin
			tmds_video <= tmds_neg18;
			bias <= bias + shl18;
		end

		// Clock 19: Apply selected mode.
		case (mode19)
			3'd0: tmds <= tmds_video;
			3'd1: tmds <= tmds_video;
			3'd2: tmds <= video_guard_band;
			3'd3: tmds <= terc4_coding;
			3'd4: tmds <= data_guard_band;
		endcase
	end
endmodule
