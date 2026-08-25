module transmitter #(
    parameter integer DATA_WIDTH = 8,
    parameter integer FIFO_DEPTH = 16,
    parameter integer PTR_WIDTH  = 4
) (
    input wire clk,
    input wire rst,

    input wire bclk,

    input wire                  tx_en,
    input wire [DATA_WIDTH-1:0] tx_in,

    output wire tx
);

  wire tsr_load;
  wire buffer_empty;
  wire not_empty = !buffer_empty;
  wire [DATA_WIDTH-1:0] data_out_internal;
  wire tsr_busy;

  // Edge detector for tsr_load (falling edge) to pop data from buffer
  reg tsr_load_prev;
  always @(posedge clk or negedge rst) begin
    if (!rst) tsr_load_prev <= 1'b0;
    else tsr_load_prev <= tsr_load;
  end
  wire buffer_read_pulse = !tsr_load && tsr_load_prev;

  // ---- BUFFER (FIFO) ----
  buffer #(
      .DATA_WIDTH(DATA_WIDTH),
      .PTR_WIDTH (PTR_WIDTH)
  ) buffer_inst (
      .clk(clk),
      .rst(rst),
      .data_in(tx_in),
      .write_en(tx_en),
      .read_en(buffer_read_pulse),
      .data_out(data_out_internal),
      .buffer_count(),
      .buffer_full(),
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
