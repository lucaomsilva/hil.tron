module uart #(
    parameter integer CLOCK     = 27000000,  // Tang Nano 9K - 27MHz
    parameter integer BAUDRATE  = 115200,    // buadrate required
    parameter integer BAUDCLOCK = 16,        // 16x oversampled clock for receiver

    parameter integer DATA_WIDTH = 8,
    parameter integer FIFO_DEPTH = 16
) (
    input wire clk,
    input wire rst,

    input wire                  tx_en,
    input wire [DATA_WIDTH-1:0] tx_in,

    input wire rx,

    output wire tx,

    output wire                  rx_data_ready,
    output wire [DATA_WIDTH-1:0] rx_out
);

  // ---- Baudrate (16x for Receiver) ----
  wire bclk_16x;
  baudrate #(
      .CLOCK(CLOCK),
      .BAUDRATE(BAUDRATE),
      .BAUDCLOCK(16)
  ) baudrate_rx_inst (
      .clk (clk),
      .rst (rst),
      .bclk(bclk_16x)
  );

  // ---- Baudrate (1x for Transmitter) ----
  wire bclk_1x;
  baudrate #(
      .CLOCK(CLOCK),
      .BAUDRATE(BAUDRATE),
      .BAUDCLOCK(1)
  ) baudrate_tx_inst (
      .clk (clk),
      .rst (rst),
      .bclk(bclk_1x)
  );

  // ---- Transmitter ----
  transmitter #(
      .DATA_WIDTH(DATA_WIDTH),
      .PTR_WIDTH ($clog2(FIFO_DEPTH))
  ) transmitter_inst (
      .clk(clk),
      .bclk(bclk_1x),
      .rst(rst),
      .tx_en(tx_en),
      .tx_in(tx_in),
      .tx(tx)
  );

  // ---- Receiver ----
  receiver #(
      .DATA_WIDTH(DATA_WIDTH),
      .PTR_WIDTH ($clog2(FIFO_DEPTH))
  ) receiver_inst (
      .clk(clk),
      .rst(rst),
      .bclk(bclk_16x),
      .rx(rx),
      .rx_en(rx_data_ready),
      .rx_out(rx_out),
      .data_ready(rx_data_ready)
  );

endmodule
