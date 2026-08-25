module baudrate #(
    parameter integer CLOCK     = 27000000,  // Tang Nano 9K - 27MHz
    parameter integer BAUDRATE  = 115200,    // buadrate required
    parameter integer BAUDCLOCK = 1          // number of tick in one BCLK
) (
    input wire clk,
    input wire rst,

    output reg bclk
);

  // Use a 32-bit Phase Accumulator for zero-error frequency generation
  // Formula: INCREMENT = (TARGET_FREQ * 2^32) / CLOCK_FREQ
  // We use 64-bit math to prevent overflow during the multiplication
  localparam [63:0] ACC_INC_64 = (64'd4294967296 * BAUDRATE * BAUDCLOCK) / CLOCK;
  localparam [31:0] ACC_INC = ACC_INC_64[31:0];

  reg [31:0] acc;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      acc  <= 32'b0;
      bclk <= 1'b0;
    end else begin
      acc  <= acc + ACC_INC;
      bclk <= acc[31];  // MSB is a perfect 50% duty cycle square wave
    end
  end

endmodule
