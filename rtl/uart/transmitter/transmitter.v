module transmitter #(
    parameter integer DATA_WIDTH = 8,
    parameter integer PTR_WIDTH  = 4
) (
    input wire clk,
    input wire rst,

    input wire bclk,

    input wire                  tx_en,
    input wire [DATA_WIDTH-1:0] tx_in,

    output wire tx,
    output wire tx_ready
);

  wire buffer_full;
  assign tx_ready = !buffer_full;

  wire buffer_empty;
  wire not_empty = !buffer_empty;
  wire [DATA_WIDTH-1:0] data_out_internal;

  wire tsr_load;
  wire tsr_busy;

  // ---- BUFFER ----
  buffer #(
      .DATA_WIDTH(DATA_WIDTH),
      .PTR_WIDTH (PTR_WIDTH)
  ) buffer_inst (
      .clk(clk),
      .rst(rst),
      .data_in(tx_in),
      .write_en(tx_en),
      .read_en(tsr_load),
      .data_out(data_out_internal),
      .buffer_count(),
      .buffer_full(buffer_full),
      .buffer_empty(buffer_empty)
  );

  // ---- Transmitter Timing Control ----
  transmitter_timing_control transmitter_timing_control (
      .clk(clk),
      .bclk(bclk),
      .rst(rst),
      .tx_start(not_empty),
      .tsr_busy(tsr_busy),
      .tsr_load(tsr_load)
  );

  // ---- Transmitter Shift Register ----
  transmitter_shift_register transmitter_shift_register_inst (
      .clk(clk),
      .bclk(bclk),
      .rst(rst),
      .tsr_load(tsr_load),
      .data_in(data_out_internal),
      .tx_out(tx),
      .tsr_busy(tsr_busy)
  );

endmodule
