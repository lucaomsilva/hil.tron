module encode_unit (
    input wire clk,
    input wire rst,

    input  wire        encode_en,
    input  wire [31:0] data_in,
    output reg         idle,

    input  wire       encode_read,
    output wire [7:0] data_out,
    output wire       encode_ready
);

  localparam S_IDLE = 2'd0;
  localparam S_SEND = 2'd1;
  localparam S_WAIT = 2'd2;

  reg [1:0] state;
  reg [1:0] byte_count;
  reg [31:0] shift_reg;

  reg [7:0] buf_data_in;
  reg buf_write_en;

  assign data_out = buf_data_in;
  assign encode_ready = buf_write_en;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      state <= S_IDLE;
      byte_count <= 2'd0;
      shift_reg <= 32'd0;
      idle <= 1'b1;
      buf_write_en <= 1'b0;
      buf_data_in <= 8'd0;
    end else begin
      buf_write_en <= 1'b0;  // default

      case (state)
        S_IDLE: begin
          idle <= 1'b1;
          if (encode_en) begin
            idle <= 1'b0;
            shift_reg <= data_in;
            byte_count <= 2'd0;
            state <= S_SEND;
          end
        end
        S_SEND: begin
          if (encode_read) begin
            buf_write_en <= 1'b1;
            buf_data_in <= shift_reg[31:24];  // Big endian
            shift_reg <= {shift_reg[23:0], 8'd0};
            state <= S_WAIT;
          end
        end
        S_WAIT: begin
          if (byte_count == 2'd3) begin
            state <= S_IDLE;
          end else begin
            byte_count <= byte_count + 1'b1;
            state <= S_SEND;
          end
        end
        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end
endmodule
