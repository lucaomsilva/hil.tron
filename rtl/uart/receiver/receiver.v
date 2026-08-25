module receiver #(
    parameter integer DATA_WIDTH = 8,
    parameter integer PTR_WIDTH  = 4
) (
    input wire clk,
    input wire rst,

    input wire bclk,  // 16x oversampled clock

    input wire rx,
    input wire rx_en,

    output wire [DATA_WIDTH-1:0] rx_out,
    output wire                  data_ready
);
  wire rsr_load;
  wire rx_done;
  wire [DATA_WIDTH-1:0] shift_data_out;
  wire buffer_empty;

  assign data_ready = !buffer_empty;

  // ---- Receiver Timing Control ----
  receiver_timing_control receiver_timing_control_inst (
      .clk(clk),
      .bclk(bclk),
      .rst(rst),
      .rx(rx),
      .rsr_load(rsr_load),
      .rx_done(rx_done)
  );

  // ---- Receiver Shift Register ----
  receiver_shift_register #(
      .DATA_WIDTH(DATA_WIDTH)
  ) receiver_shift_register_inst (
      .clk(clk),
      .rst(rst),
      .rsr_load(rsr_load),
      .rx(rx),
      .data_out(shift_data_out)
  );

  // ---- Buffer ----
  buffer #(
      .DATA_WIDTH(DATA_WIDTH),
      .PTR_WIDTH (PTR_WIDTH)
  ) buffer_inst (
      .clk(clk),
      .rst(rst),
      .data_in(shift_data_out),
      .write_en(rx_done),
      .read_en(rx_en),
      .data_out(rx_out),
      .buffer_count(),
      .buffer_full(),
      .buffer_empty(buffer_empty)
  );

endmodule
