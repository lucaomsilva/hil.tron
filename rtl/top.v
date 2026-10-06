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

  // --- Input Control ---
  wire decode_en;
  wire decode_free;
  wire decode_ready;
  wire decode_read;
  wire setpoint_en;
  wire control_en;
  wire kp_en;
  wire ki_en;
  wire kd_en;

  input_control input_control_inst (
      .clk(CLK),
      .rst(1'b1),
      .opcode_en(rx_ready),
      .opcode(rx_data),
      .opcode_done(rx_en),
      .decode_en(decode_en),
      .decode_free(decode_free),
      .decode_ready(decode_ready),
      .decode_read(decode_read),
      .setpoint_en(setpoint_en),
      .control_en(control_en),
      .kp_en(kp_en),
      .ki_en(ki_en),
      .kd_en(kd_en)
  );

  // --- Decode & Encode Loopback ---
  wire [31:0] decode_data;

  // --- Decode ---
  decode decode_inst (
      .clk(CLK),
      .rst(1'b1),
      .decode_en(decode_en),
      .data_in(rx_data),
      .decode_free(decode_free),
      .decode_ready(decode_ready),
      .decode_data(decode_data),
      .decode_read(decode_read)
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
      .encode_en(encode_en),
      .data_decode(encode_data_in),
      .encode_idle(),
      .encode_ready(tx_en),
      .encode_read(tx_ready),
      .data_encode(tx_data)
  );

  // --- Setpoint ---
  wire [31:0] setpoint_out;

  register setpoint_inst (
      .clk(CLK),
      .rst(1'b1),
      .reg_en(setpoint_en),
      .write_en(decode_ready),
      .data_in(decode_data),
      .data_out(setpoint_out)
  );

  // --- Kp Register ---
  wire [31:0] kp_out;

  register #(
      .INIT_VAL(32'h00058000)
  ) kp_register_inst (
      .clk(CLK),
      .rst(1'b1),
      .reg_en(kp_en),
      .write_en(decode_ready),
      .data_in(decode_data),
      .data_out(kp_out)
  );

  // --- Ki Register ---
  wire [31:0] ki_out;

  register #(
      .INIT_VAL(32'h00000000)
  ) ki_register_inst (
      .clk(CLK),
      .rst(1'b1),
      .reg_en(ki_en),
      .write_en(decode_ready),
      .data_in(decode_data),
      .data_out(ki_out)
  );

  // --- Kd Register ---
  wire [31:0] kd_out;

  register #(
      .INIT_VAL(32'h00000000)
  ) kd_register_inst (
      .clk(CLK),
      .rst(1'b1),
      .reg_en(kd_en),
      .write_en(decode_ready),
      .data_in(decode_data),
      .data_out(kd_out)
  );

  // --- Controller ---
  wire encode_en;

  controller controller_inst (
      .clk(CLK),
      .rst(1'b1),
      .control_en(control_en),
      .setpoint(setpoint_out),
      .kp(kp_out),
      .ki(ki_out),
      .kd(kd_out),
      .feedback(decode_data),
      .control_out(encode_data_in),
      .encode_en(encode_en)
  );

  assign LED = 6'b111111;

endmodule
