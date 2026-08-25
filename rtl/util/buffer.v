module buffer #(
    parameter integer DATA_WIDTH = 8,
    parameter integer PTR_WIDTH  = 4
) (
    input wire clk,
    input wire rst,

    input wire [DATA_WIDTH-1:0] data_in,
    input wire                  write_en,
    input wire                  read_en,

    output wire [DATA_WIDTH-1:0] data_out,
    output reg  [   PTR_WIDTH:0] buffer_count,
    output reg                   buffer_full,
    output reg                   buffer_empty
);

  localparam integer DEPTH = 1 << PTR_WIDTH;

  reg [DATA_WIDTH-1:0] memory[DEPTH];
  reg [PTR_WIDTH-1:0] write_ptr;
  reg [PTR_WIDTH-1:0] read_ptr;

  // Continuous reading based on current pointer
  assign data_out = memory[read_ptr];

  // Only allow operations if buffer is not at limits
  wire write_do = write_en && (buffer_count < DEPTH);
  wire read_do = read_en && (buffer_count > 0);

  initial begin
    buffer_empty = 1'b1;  // Initially, buffer is empty
  end

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      write_ptr    <= 0;
      read_ptr     <= 0;
      buffer_count <= 0;
      buffer_full  <= 1'b0;
      buffer_empty <= 1'b1;
    end else begin
      if (write_do) begin
        memory[write_ptr] <= data_in;
        write_ptr <= write_ptr + 1'b1;
      end

      if (read_do) begin
        read_ptr <= read_ptr + 1'b1;
      end

      if (write_do && !read_do) begin
        buffer_count <= buffer_count + 1'b1;
        buffer_full  <= (buffer_count + 1'b1 == DEPTH);
        buffer_empty <= 1'b0;
      end else if (!write_do && read_do) begin
        buffer_count <= buffer_count - 1'b1;
        buffer_full  <= 1'b0;
        buffer_empty <= (buffer_count - 1'd1 == 0);
      end
    end
  end
endmodule
