module baudrate
#(
    parameter integer CLOCK = 27000000,  // Tang Nano 9K - 27MHz
    parameter integer BAUDRATE = 115200, // buadrate required
    parameter integer BAUDCLOCK = 1      // number of tick in one BCLK
)
(
    input wire clk,
    input wire rst,
    output reg bclk
);

localparam integer LIMITER = CLOCK / (BAUDRATE * BAUDCLOCK);
localparam integer COUNTER_WIDTH = $clog2(LIMITER);

reg [COUNTER_WIDTH-1:0] counter;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        counter <= 0;
        bclk <= 0;
    end else begin
        if (counter < LIMITER/2 - 1) begin
            counter <= counter + 1;
        end else begin
            counter <= 0;
            bclk <= ~bclk;
        end
    end
end

endmodule
