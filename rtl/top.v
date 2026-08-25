module top (
    input CLK,
    input RST,

    input BTN,

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

  // ---- UART ----
  uart uart_inst (
      .clk(CLK),
      .rst(RST),
      .tx_en(tx_en_pulse),
      .tx(TX_OUT)
  );

  // Tie-off unused LEDs (active low)
  assign LED = 6'b111111;

endmodule
