module transmitter_timing_control (
    input wire clk,
    input wire rst,

    input wire bclk,

    input wire tx_start,
    input wire tsr_busy,

    output reg tsr_load
);

  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] LOAD = 2'b01;
  localparam [1:0] SHIFT = 2'b10;

  localparam integer STATES = 3;

  initial begin
    tsr_load = 0;
  end

  reg bclk_prev;
  always @(posedge clk or negedge rst) begin
    if (!rst) bclk_prev <= 1'b0;
    else bclk_prev <= bclk;
  end
  wire bclk_edge = bclk && !bclk_prev;

  reg [$clog2(STATES)-1:0] state = IDLE;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      state    <= IDLE;
      tsr_load <= 1'b0;
    end else begin
      if (bclk_edge) begin
        case (state)
          IDLE: begin
            tsr_load <= 1'b0;
            if (tx_start) begin
              state    <= LOAD;
              tsr_load <= 1'b1;
            end
          end
          LOAD: begin
            state <= SHIFT;
          end
          SHIFT: begin
            tsr_load <= 1'b0;
            if (!tsr_busy) begin
              state <= IDLE;
            end
          end
          default: begin
            state <= IDLE;
          end
        endcase
      end
    end
  end

endmodule
