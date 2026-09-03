module top (
    input CLK,
    input RST,

    input BTN,

    input  RX_IN,
    output TX_OUT,

    output [5:0] LED
);

  // --- UART ---
  wire [7:0] rx_data;
  wire rx_ready;
  wire rx_en;

  wire tx_ready;
  wire tx_en;
  wire [7:0] tx_data;

  uart uart_inst (
      .clk(CLK),
      .rst(RST),
      .tx_en(tx_en),
      .tx_in(tx_data),
      .tx_ready(tx_ready),
      .rx(RX_IN),
      .rx_en(rx_en),
      .tx(TX_OUT),
      .rx_out(rx_data),
      .rx_ready(rx_ready)
  );

  // --- Decode & Encode Loopback ---
  wire [31:0] loop_data;
  wire        loop_ready;
  wire        loop_idle;

  // --- Decode ---
  decode decode_inst (
      .clk(CLK),
      .rst(RST),
      .data_ready(rx_ready),
      .data_encode(rx_data),
      .decode_en(rx_en),
      .decode_ready(loop_ready),
      .data_decode(loop_data),
      .decode_read(loop_idle)
  );

  // --- Encode ---
  encode encode_inst (
      .clk(CLK),
      .rst(RST),
      .encode_en(loop_ready),
      .data_decode(loop_data),
      .encode_idle(loop_idle),
      .encode_ready(tx_en),
      .encode_read(tx_ready),
      .data_encode(tx_data)
  );

endmodule
