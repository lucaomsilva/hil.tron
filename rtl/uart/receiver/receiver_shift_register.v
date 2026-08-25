module receiver_shift_register #(
    parameter integer DATA_WIDTH = 8
) (
    input wire clk,
    input wire rst,

    input wire rsr_load,
    input wire rx,

    output reg [DATA_WIDTH-1:0] data_out
);

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      data_out <= {DATA_WIDTH{1'b0}};
    end else if (rsr_load) begin
      data_out <= {rx, data_out[DATA_WIDTH-1:1]};
    end
  end

endmodule
