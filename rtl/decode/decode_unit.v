module decode_unit (
    input wire clk,
    input wire rst,

    input  wire       data_ready,
    input  wire [7:0] data_in,
    output reg        read_en,

    output reg         decode_ready,
    output reg  [31:0] data_out,
    input  wire        decode_read
);

  localparam S_WAIT = 2'd0;
  localparam S_READ = 2'd1;
  localparam S_DONE = 2'd2;

  reg [ 1:0] state;
  reg [ 1:0] byte_count;
  reg [31:0] shift_reg;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      state <= S_WAIT;
      byte_count <= 2'd0;
      shift_reg <= 32'd0;
      decode_ready <= 1'b0;
      data_out <= 32'd0;
      read_en <= 1'b0;
    end else begin
      read_en <= 1'b0;  // Default

      case (state)
        S_WAIT: begin
          if (data_ready) begin
            read_en <= 1'b1;
            shift_reg <= {shift_reg[23:0], data_in};  // Big endian
            state <= S_READ;
          end
        end
        S_READ: begin
          if (byte_count == 2'd3) begin
            state <= S_DONE;
          end else begin
            byte_count <= byte_count + 1'b1;
            state <= S_WAIT;
          end
        end
        S_DONE: begin
          decode_ready <= 1'b1;
          data_out <= shift_reg;
          if (decode_read && decode_ready) begin
            decode_ready <= 1'b0;
            byte_count <= 2'd0;
            state <= S_WAIT;
          end
        end
        default: begin
          state <= S_WAIT;
        end
      endcase
    end
  end
endmodule
