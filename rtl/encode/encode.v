module encode (
    input wire clk,
    input wire rst,

    input  wire        encode_en,
    input  wire [31:0] data_decode,
    output wire        encode_idle,

    output wire       encode_ready,
    input  wire       encode_read,
    output wire [7:0] data_encode
);

  wire [7:0] unit_data_out;
  wire unit_encode_ready;
  wire buf_full;
  wire buf_empty;

  assign encode_ready = ~buf_empty;

  encode_unit encode_unit_inst (
      .clk(clk),
      .rst(rst),
      .encode_en(encode_en),
      .data_in(data_decode),
      .idle(encode_idle),
      .encode_read(~buf_full),
      .data_out(unit_data_out),
      .encode_ready(unit_encode_ready)
  );

  buffer #(
      .DATA_WIDTH(8),
      .PTR_WIDTH (6)
  ) tx_buffer (
      .clk(clk),
      .rst(rst),
      .data_in(unit_data_out),
      .write_en(unit_encode_ready),
      .read_en(encode_read),
      .data_out(data_encode),
      .buffer_count(),
      .buffer_full(buf_full),
      .buffer_empty(buf_empty)
  );

endmodule
