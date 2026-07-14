module i2s_receiver
(
	input sys_clk,
	input reset_n,
	input i2s_clk,
	input i2s_ws,
	input i2s_data,
	output reg signed [15:0] left,
	output reg signed [15:0] right
);

always @(posedge sys_clk) begin : i2s_proc
	reg signed [15:0] i2s_buf[2];
	reg  [4:0] i2s_cnt;
	reg        old_clk, old_ws, side, i2s_next;
	reg        i2s_clk_meta, i2s_clk_sync;
	reg        i2s_ws_meta, i2s_ws_sync;
	reg        i2s_data_meta, i2s_data_sync;
	reg        i2s_data_prev;
	reg  [2:0] i2s_data_hist;

	// External I2S is asynchronous to sys_clk. Double-flop synchronize to reduce
	// metastability and random bit glitches that present as static.
	i2s_clk_meta  <= i2s_clk;
	i2s_clk_sync  <= i2s_clk_meta;
	i2s_ws_meta   <= i2s_ws;
	i2s_ws_sync   <= i2s_ws_meta;
	i2s_data_meta <= i2s_data;
	i2s_data_sync <= i2s_data_meta;
	i2s_data_hist <= {i2s_data_hist[1:0], i2s_data_sync};

	old_clk <= i2s_clk_sync;
	if (i2s_clk_sync && ~old_clk) begin
		if (~i2s_cnt[4]) begin // Ignore any bits that overflow.
			i2s_cnt <= i2s_cnt + 1'd1;
			i2s_buf[side][4'd15 - i2s_cnt[3:0]] <= i2s_data_prev;
		end
		i2s_data_prev <= ((i2s_data_hist[2] & i2s_data_hist[1]) |
		                  (i2s_data_hist[2] & i2s_data_hist[0]) |
		                  (i2s_data_hist[1] & i2s_data_hist[0]));
		old_ws <= i2s_ws_sync;
		if (old_ws != i2s_ws_sync)
			i2s_next <= 1;
	end

	// Standard I2S data is sampled on BCLK rising edges; advance the word
	// boundary on the opposite edge after the one-bit I2S delay is observed.
	if (~i2s_clk_sync && old_clk) begin
		if (i2s_next) begin
			i2s_cnt <= 0;
			side <= i2s_ws_sync;
			i2s_next <= 0;

			if (~i2s_ws_sync) begin
				i2s_buf[0] <= 16'd0;
				i2s_buf[1] <= 16'd0;
				left <= i2s_buf[0];
				right <= i2s_buf[1];
			end
		end
	end

	if (~reset_n) begin
		i2s_clk_meta <= 1'b0;
		i2s_clk_sync <= 1'b0;
		i2s_ws_meta <= 1'b0;
		i2s_ws_sync <= 1'b0;
		i2s_data_meta <= 1'b0;
		i2s_data_sync <= 1'b0;
		old_clk <= 1'b0;
		old_ws <= 1'b0;
		side <= 1'b0;
		i2s_cnt <= 0;
		i2s_next <= 1'b0;
		i2s_buf[0] <= 16'd0;
		i2s_buf[1] <= 16'd0;
		i2s_data_prev <= 1'b0;
		i2s_data_hist <= 3'b000;
		left <= 16'sd0;
		right <= 16'sd0;
	end
end

endmodule
