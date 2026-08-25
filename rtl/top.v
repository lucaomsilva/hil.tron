module top (
    input CLK,
    input RST,

    input BTN,

    input  RX_IN,
    output TX_OUT,

    output [5:0] LED
);

  // ---- Debounce ----
  wire btn_debounced;
  debounce debounce_inst (
      .clk(CLK),
      .pb_in(!BTN),
      .pb_out(btn_debounced)
  );

  // Edge detector: Pass the button signal to one cycle of clock
  reg btn_prev;
  always @(posedge CLK or negedge RST) begin
    if (!RST) btn_prev <= 1'b0;
    else btn_prev <= btn_debounced;
  end
  wire tx_en_pulse = btn_debounced && !btn_prev;

  wire [7:0] rx_data;
  wire rx_ready;

  // ---- UART ----
  uart uart_inst (
      .clk(CLK),
      .rst(RST),
      .tx_en(tx_en_pulse || rx_ready),
      .tx_in(tx_en_pulse ? 8'h41 : rx_data),
      .rx(RX_IN),
      .tx(TX_OUT),
      .rx_out(rx_data),
      .rx_data_ready(rx_ready)
  );

  // Display the received byte on the 6 onboard LEDs
  // LEDs are active low, so we invert the data bits
  assign LED = ~rx_data[5:0];

endmodule
