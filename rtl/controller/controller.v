module controller (
    input wire clk,
    input wire rst,

    input wire control_en,

    input wire [31:0] setpoint,
    input wire [31:0] kp,
    input wire [31:0] ki,
    input wire [31:0] feedback,

    output reg [31:0] control_out,
    output reg encode_en
);

  reg signed [32:0] error;

  reg signed [64:0] p_prod_full;
  reg signed [63:0] p_product;
  reg signed [47:0] p_shifted;

  reg signed [64:0] i_prod_full;
  reg signed [63:0] i_product;
  reg signed [47:0] i_shifted;

  reg signed [47:0] accumulator;
  reg signed [48:0] acc_full;
  reg signed [48:0] pi_sum_full;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      control_out <= 32'd0;
      encode_en <= 1'b0;
      accumulator <= 48'd0;
    end else begin
      encode_en <= 1'b0;
      if (control_en) begin
          error = $signed(setpoint) - $signed(feedback);

          // Proportional Action
          p_prod_full = $signed(kp) * error;

          if (p_prod_full[64:63] == 2'b01) p_product = 64'h7FFFFFFFFFFFFFFF;
          else if (p_prod_full[64:63] == 2'b10) p_product = 64'h8000000000000000;
          else p_product = p_prod_full[63:0];

          p_shifted = p_product >>> 16;

          // Integral Action
          i_prod_full = $signed(ki) * error;

          if (i_prod_full[64:63] == 2'b01) i_product = 64'h7FFFFFFFFFFFFFFF;
          else if (i_prod_full[64:63] == 2'b10) i_product = 64'h8000000000000000;
          else i_product = i_prod_full[63:0];

          i_shifted = i_product >>> 16;

          // Accumulator with Anti-windup
          acc_full = accumulator + i_shifted;
          if (acc_full > 49'sd140737488355327) accumulator = 48'sd140737488355327; // 48'h7FFFFFFFFFFF
          else if (acc_full < -49'sd140737488355328) accumulator = -48'sd140737488355328; // 48'h800000000000
          else accumulator = acc_full[47:0];

          // PI Sum and Saturation
          pi_sum_full = p_shifted + accumulator;

          if (pi_sum_full > 49'sd2147483647) control_out <= 32'h7FFFFFFF;
          else if (pi_sum_full < -49'sd2147483648) control_out <= 32'h80000000;
          else control_out <= pi_sum_full[31:0];

        encode_en <= 1'b1;
      end
    end
  end

endmodule
