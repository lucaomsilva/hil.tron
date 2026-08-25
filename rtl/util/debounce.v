module debounce #(
    // Clock = 27MHz, 270000 cycles/period = 10 milliseconds.
    parameter integer THRESHOLD = 270000
) (
    input clk,
    input pb_in,
    output reg pb_out
);

  reg sync_0, sync_1;

  always @(posedge clk) begin
    sync_0 <= pb_in;
    sync_1 <= sync_0;
  end

  reg [19:0] counter = 20'd0;

  always @(posedge clk) begin
    if (sync_1 != pb_out) begin
      counter <= counter + 1'b1;

      if (counter == THRESHOLD) begin
        pb_out  <= sync_1;
        counter <= 20'b0;
      end
    end else begin
      counter <= 20'd0;
    end
  end

endmodule
