module uart #(
    parameter integer CLOCK = 27000000,  // Tang Nano 9K - 27MHz
    parameter integer BAUDRATE = 115200, // buadrate required
    parameter integer BAUDCLOCK = 1,     // number of tick in one BCLK

    parameter integer DATA_WIDTH = 8,
    parameter integer FIFO_DEPTH = 16
) (
    input wire clk,
    input wire rst,
    input wire tx_en,

    output wire tx
);

  // ---- Baudrate ----
  wire bclk;

  baudrate #(
      .CLOCK(CLOCK),
      .BAUDRATE(BAUDRATE),
      .BAUDCLOCK(BAUDCLOCK)
  ) baudrate_inst (
      .clk (clk),
      .rst (rst),
      .bclk(bclk)
  );

  // ---- Transmitter ----
  transmitter transmitter_inst (
      .clk(clk),
      .bclk(bclk),
      .rst(rst),
      .tx_en(tx_en),
      .tx_in(8'h41),  // Static 'A'
      .tx(tx)
  );

endmodule
