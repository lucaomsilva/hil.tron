module controller (
    input wire clk,
    input wire rst,

    input wire control_en,

    input wire [31:0] reference,
    input wire [31:0] data_in,

    output reg [31:0] data_out,
    output reg encode_en
);

  localparam Kp = 10;

  wire [31:0] error = reference - data_in;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      data_out <= 32'd0;
      encode_en <= 1'b0;
    end else begin
      encode_en <= 1'b0;
      if (control_en) begin
        data_out <= Kp * error;
        encode_en <= 1'b1;
      end
    end
  end

endmodule
