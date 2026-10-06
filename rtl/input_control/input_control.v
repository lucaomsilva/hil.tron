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

    // Setpoint Interface
    output reg setpoint_en,

    // Control Interface
    output reg control_en,
    output reg kp_en,
    output reg ki_en,
    output reg kd_en
);

  localparam IDLE        = 2'd0;
  localparam DATA        = 2'd1;
  localparam WAIT        = 2'd2;

  localparam OP_DATA     = 8'h00;
  localparam OP_SETPOINT = 8'h01;
  localparam OP_KP       = 8'h02;
  localparam OP_KI       = 8'h03;
  localparam OP_KD       = 8'h04;

  reg [1:0] state;
  reg [2:0] byte_count;
  reg is_data_opcode;

  assign opcode_done = (state == IDLE) ? 1'b1 : (state == DATA) ? decode_free : 1'b0;

  assign decode_en   = (state == DATA) ? opcode_en : 1'b0;

  wire opcode_transfer = (state == IDLE) && opcode_en && opcode_done;
  wire data_transfer = (state == DATA) && opcode_en && decode_free;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      state <= IDLE;
      decode_read <= 1'b0;
      setpoint_en <= 1'b0;
      control_en <= 1'b0;
      kp_en <= 1'b0;
      ki_en <= 1'b0;
      kd_en <= 1'b0;
      is_data_opcode <= 1'b0;
    end else begin
      decode_read <= 1'b0;
      setpoint_en <= 1'b0;
      control_en <= 1'b0;
      kp_en <= 1'b0;
      ki_en <= 1'b0;
      kd_en <= 1'b0;

      case (state)
        IDLE: begin
          if (opcode_transfer) begin
            case (opcode)
              OP_DATA: begin
                state <= DATA;
                byte_count <= 3'd0;
                is_data_opcode <= 1'b1;
                setpoint_en <= 1'b0;
                kp_en <= 1'b0;
                ki_en <= 1'b0;
                kd_en <= 1'b0;
              end
              OP_SETPOINT: begin
                state <= DATA;
                byte_count <= 3'd0;
                is_data_opcode <= 1'b0;
                setpoint_en <= 1'b1;
                kp_en <= 1'b0;
                ki_en <= 1'b0;
                kd_en <= 1'b0;
              end
              OP_KP: begin
                state <= DATA;
                byte_count <= 3'd0;
                is_data_opcode <= 1'b0;
                setpoint_en <= 1'b0;
                kp_en <= 1'b1;
                ki_en <= 1'b0;
                kd_en <= 1'b0;
              end
              OP_KI: begin
                state <= DATA;
                byte_count <= 3'd0;
                is_data_opcode <= 1'b0;
                setpoint_en <= 1'b0;
                kp_en <= 1'b0;
                ki_en <= 1'b1;
                kd_en <= 1'b0;
              end
              OP_KD: begin
                state <= DATA;
                byte_count <= 3'd0;
                is_data_opcode <= 1'b0;
                setpoint_en <= 1'b0;
                kp_en <= 1'b0;
                ki_en <= 1'b0;
                kd_en <= 1'b1;
              end
              default: begin
                is_data_opcode <= 1'b0;
                setpoint_en <= 1'b0;
                kp_en <= 1'b0;
                ki_en <= 1'b0;
                kd_en <= 1'b0;
              end
            endcase
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
            if (is_data_opcode) begin
              control_en <= 1'b1;
            end
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
