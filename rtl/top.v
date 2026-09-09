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
      .rst(1'b1),
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
  wire [31:0] decode_data_out;
  wire        decode_ready;

  // --- Decode ---
  decode decode_inst (
      .clk(CLK),
      .rst(1'b1),
      .data_ready(rx_ready),
      .data_encode(rx_data),
      .decode_en(rx_en),
      .decode_ready(decode_ready),
      .data_decode(decode_data_out),
      .decode_read(decode_ready)
  );

  wire [31:0] encode_data_in;
  wire rst_db;

  debounce debounce_rst (
      .clk(CLK),
      .pb_in(RST),
      .pb_out(rst_db)
  );

  reg rst_prev;
  always @(posedge CLK) begin
    rst_prev <= rst_db;
  end
  wire rst_edge = rst_db && !rst_prev;

  // --- Encode ---
  encode encode_inst (
      .clk(CLK),
      .rst(1'b1),
      .encode_en(btn_edge),
      .data_decode(encode_data_in),
      .encode_idle(),
      .encode_ready(tx_en),
      .encode_read(tx_ready),
      .data_encode(tx_data)
  );

  wire btn_db;
  debounce debounce_btn (
      .clk(CLK),
      .pb_in(BTN),
      .pb_out(btn_db)
  );

  reg btn_prev;
  always @(posedge CLK) begin
    btn_prev <= btn_db;
  end
  wire btn_edge = btn_db && !btn_prev;
  wire state;
  wire [31:0] reference_out;

  // --- Reference ---
  reference reference_inst (
      .clk(CLK),
      .rst(1'b1),
      .reg_en(rst_edge),
      .write_en(decode_ready),
      .data_in(decode_data_out),
      .state_out(state),
      .data_out(reference_out)
  );

  // --- Controller ---
  controller controller_inst (
      .reference(reference_out),
      .data_in  (decode_data_out),
      .data_out (encode_data_in)
  );

  assign LED[1] = state;

endmodule
