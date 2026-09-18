module controller #(
    parameter signed [31:0] Kp = 32'h00058000
) (
    input wire clk,
    input wire rst,

    input wire control_en,

    input wire [31:0] reference,
    input wire [31:0] data_in,

    output reg [31:0] data_out,
    output reg encode_en
);

  reg signed [32:0] error;
  reg signed [64:0] p_prod_full;
  reg signed [63:0] p_product;
  reg signed [47:0] p_shifted;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      data_out  <= 32'd0;
      encode_en <= 1'b0;
    end else begin
      encode_en <= 1'b0;
      if (control_en) begin
          error = $signed(reference) - $signed(data_in);

          p_prod_full = $signed(Kp) * error;

          if (p_prod_full[64:63] == 2'b01) p_product = 64'h7FFFFFFFFFFFFFFF;
          else if (p_prod_full[64:63] == 2'b10) p_product = 64'h8000000000000000;
          else p_product = p_prod_full[63:0];

          p_shifted = p_product >>> 16;

          if (p_shifted > 48'sd2147483647) data_out <= 32'h7FFFFFFF;
          else if (p_shifted < -48'sd2147483648) data_out <= 32'h80000000;
          else data_out <= p_shifted[31:0];

        encode_en <= 1'b1;
      end
    end
  end

endmodule
