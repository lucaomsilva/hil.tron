module input_control (
    input wire clk,
    input wire rst,

    // UART RX Interface
    input  wire       opcode_en,
    input  wire [7:0] opcode,
    output wire       opcode_done,

    // Decode Interface
    output wire decode_en,
    input  wire decode_free,

    input  wire decode_ready,
    output reg  decode_read,

    // Reference Interface
    output reg ref_en,

    // Control Interface
    output reg control_en
);

  localparam IDLE = 2'd0;
  localparam DATA = 2'd1;
  localparam WAIT = 2'd2;

  reg [1:0] state;
  reg [2:0] byte_count;

  assign opcode_done = (state == IDLE) ? 1'b1 : (state == DATA) ? decode_free : 1'b0;

  assign decode_en   = (state == DATA) ? opcode_en : 1'b0;

  wire opcode_transfer = (state == IDLE) && opcode_en && opcode_done;
  wire data_transfer = (state == DATA) && opcode_en && decode_free;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      state <= IDLE;
      decode_read <= 1'b0;
      ref_en <= 1'b0;
      control_en <= 1'b0;
    end else begin
      decode_read <= 1'b0;
      ref_en <= 1'b0;
      control_en <= 1'b0;

      case (state)
        IDLE: begin
          if (opcode_transfer) begin
            if (opcode == 8'h00 || opcode == 8'h01) begin
              state <= DATA;
              byte_count <= 3'd0;

              if (opcode == 8'h01) begin
                ref_en <= 1'b1;
              end
            end
          end
        end

        DATA: begin
          if (data_transfer) begin
            if (byte_count == 3'd3) begin
              state <= WAIT;
            end else begin
              byte_count <= byte_count + 1'b1;
            end
          end
        end

        WAIT: begin
          if (decode_ready) begin
            decode_read <= 1'b1;
            control_en <= 1'b1;
            state <= IDLE;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
