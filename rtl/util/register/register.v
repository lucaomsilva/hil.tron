module register #(
    parameter [31:0] INIT_VAL = 32'd0
) (
    input wire clk,
    input wire rst,

    input wire        reg_en,
    input wire        write_en,
    input wire [31:0] data_in,

    output wire [31:0] data_out
);

  localparam IDLE = 1'b0;
  localparam SAVE = 1'b1;

  reg [31:0] data_reg;
  assign data_out = data_reg;

  reg state;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      state    <= IDLE;
      data_reg <= INIT_VAL;
    end else begin
      case (state)
        IDLE: begin
          if (reg_en) begin
            state <= SAVE;
          end
        end
        SAVE: begin
          if (write_en) begin
            state    <= IDLE;
            data_reg <= data_in;
          end
        end
        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
