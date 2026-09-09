module controller (
    input wire [31:0] reference,
    input wire [31:0] data_in,

    output wire [31:0] data_out
);

  localparam Kp = 10;

  wire [31:0] error = reference - data_in;
  assign data_out = Kp * error;

endmodule
