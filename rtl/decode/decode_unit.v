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

  localparam WAIT = 2'd0;
  localparam READ = 2'd1;
  localparam DONE = 2'd2;

  reg [ 1:0] state;
  reg [ 1:0] byte_count;
  reg [31:0] shift_reg;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      state <= WAIT;
      byte_count <= 2'd0;
      shift_reg <= 32'd0;
      decode_ready <= 1'b0;
      data_out <= 32'd0;
      read_en <= 1'b0;
    end else begin
      read_en <= 1'b0;  // Default

      case (state)
        WAIT: begin
          if (data_ready) begin
            read_en <= 1'b1;
            shift_reg <= {data_in, shift_reg[31:8]};  // Little endian
            state <= READ;
          end
        end
        READ: begin
          if (byte_count == 2'd3) begin
            state <= DONE;
          end else begin
            byte_count <= byte_count + 1'b1;
            state <= WAIT;
          end
        end
        DONE: begin
          decode_ready <= 1'b1;
          data_out <= shift_reg;
          if (decode_read && decode_ready) begin
            decode_ready <= 1'b0;
            byte_count <= 2'd0;
            state <= WAIT;
          end
        end
        default: begin
          state <= WAIT;
        end
      endcase
    end
  end
endmodule
