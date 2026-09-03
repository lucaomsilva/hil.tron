module decode (
    input wire clk,
    input wire rst,

    input  wire       data_ready,
    input  wire [7:0] data_encode,
    output wire       decode_en,

    output wire        decode_ready,
    output wire [31:0] data_decode,
    input  wire        decode_read
);

  wire [7:0] buf_data_out;
  wire buf_empty;
  wire buf_full;
  wire unit_read_en;

  assign decode_en = ~buf_full;

  decode_unit decode_unit_inst (
      .clk(clk),
      .rst(rst),
      .data_ready(~buf_empty),
      .data_in(buf_data_out),
      .read_en(unit_read_en),
      .decode_ready(decode_ready),
      .data_out(data_decode),
      .decode_read(decode_read)
  );

  buffer #(
      .DATA_WIDTH(8),
      .PTR_WIDTH (6)
  ) rx_buffer (
      .clk(clk),
      .rst(rst),
      .data_in(data_encode),
      .write_en(data_ready),
      .read_en(unit_read_en),
      .data_out(buf_data_out),
      .buffer_count(),
      .buffer_full(buf_full),
      .buffer_empty(buf_empty)
  );

endmodule
