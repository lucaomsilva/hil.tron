module receiver_timing_control (
    input wire clk,
    input wire rst,

    input wire bclk,  // 16x oversampled clock

    input wire rx,

    output reg rsr_load,
    output reg rx_done
);

  localparam [1:0] IDLE  = 2'b00;
  localparam [1:0] START = 2'b01;
  localparam [1:0] DATA  = 2'b10;
  localparam [1:0] STOP  = 2'b11;

  reg bclk_prev;
  always @(posedge clk or negedge rst) begin
    if (!rst) bclk_prev <= 1'b0;
    else bclk_prev <= bclk;
  end
  wire bclk_edge = bclk && !bclk_prev;

  // Synchronize rx to avoid metastability
  reg rx_sync1, rx_sync2;
  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      rx_sync1 <= 1'b1;
      rx_sync2 <= 1'b1;
    end else begin
      rx_sync1 <= rx;
      rx_sync2 <= rx_sync1;
    end
  end

  reg [1:0] state = IDLE;
  reg [3:0] tick_counter;
  reg [2:0] bit_counter;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      state <= IDLE;
      tick_counter <= 4'b0;
      bit_counter <= 3'b0;
      rsr_load <= 1'b0;
      rx_done <= 1'b0;
    end else begin
      rsr_load <= 1'b0;
      rx_done  <= 1'b0;

      if (bclk_edge) begin
        case (state)
          IDLE: begin
            if (rx_sync2 == 1'b0) begin
              state <= START;
              tick_counter <= 4'd1;
            end
          end
          START: begin
            tick_counter <= tick_counter + 1'b1;
            if (tick_counter == 4'd8) begin
              if (rx_sync2 == 1'b0) begin
                state <= DATA;
                tick_counter <= 4'b0;
                bit_counter <= 3'b0;
              end else begin
                // False start bit
                state <= IDLE;
              end
            end
          end
          DATA: begin
            tick_counter <= tick_counter + 1'b1;
            if (tick_counter == 4'd15) begin
              rsr_load <= 1'b1;
              if (bit_counter == 3'd7) begin
                state <= STOP;
                tick_counter <= 4'b0;
              end else begin
                bit_counter <= bit_counter + 1'b1;
              end
            end
          end
          STOP: begin
            tick_counter <= tick_counter + 1'b1;
            if (tick_counter == 4'd15) begin
              if (rx_sync2 == 1'b1) begin
                rx_done <= 1'b1;
              end
              state <= IDLE;
            end
          end
          default: state <= IDLE;
        endcase
      end
    end
  end
endmodule
