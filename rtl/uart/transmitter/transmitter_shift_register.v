module transmitter_shift_register #(
    parameter integer DATA_WIDTH = 8
) (
    input wire clk,
    input wire rst,

    input wire bclk,

    input wire tsr_load,
    input wire [DATA_WIDTH-1:0] data_in,

    output reg tx_out,
    output reg tsr_busy
);

  localparam integer REG_WIDTH = 10;

  localparam [0:0] BIT_START   = 1'b0;
  localparam [0:0] BIT_STOP    = 1'b1;
  localparam [9:0] DEFAULT_REG = 10'b1111111111;

  reg [REG_WIDTH-1:0] shift_reg = DEFAULT_REG;
  reg [$clog2(REG_WIDTH)-1:0] bit_counter;

  // TODO: make stop options
  // TODO: make parity options
  // TODO: make break control options

  initial begin
    tx_out = 1'b1;
  end

  reg bclk_prev;
  always @(posedge clk or negedge rst) begin
    if (!rst) bclk_prev <= 1'b0;
    else bclk_prev <= bclk;
  end
  wire bclk_edge = bclk && !bclk_prev;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      shift_reg   <= DEFAULT_REG;
      bit_counter <= 4'b0;
      tsr_busy    <= 1'b0;
      tx_out      <= 1'b1;
    end else if (tsr_load) begin
      shift_reg   <= {BIT_STOP, data_in, BIT_START};
      bit_counter <= REG_WIDTH;
      tsr_busy    <= 1'b1;
    end else if (bclk_edge && tsr_busy) begin
      tx_out      <= shift_reg[0];
      shift_reg   <= {1'b1, shift_reg[REG_WIDTH-1:1]};
      bit_counter <= bit_counter - 1'b1;

      if (bit_counter == 0) begin
        tsr_busy <= 1'b0;
      end
    end
  end

endmodule
