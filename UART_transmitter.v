module UART_transmitter #(
    parameter UART_DATA_WIDTH = 8,
    parameter BAUD_RATE = 30,
    parameter CLOCK_FREQ = 90,
    parameter PARITY_BIT = 1
)(
    input reg[UART_DATA_WIDTH-1:0] data,
    input reset,
    input clk,
    input valid,
    output reg ready,
    output reg tx
);
parameter COUNTER_WIDTH =10;

wire [COUNTER_WIDTH-1:0] data1;
reg load1 ;
reg enable1 ;
wire[COUNTER_WIDTH-1:0] cnt1;
wire ovf1;

wire [COUNTER_WIDTH-1:0] data2;
reg load2;
reg enable2;
wire[COUNTER_WIDTH-1:0] cnt2;
wire ovf2;

localparam WAIT_TRANSMISSION = 0,
    START = 1,
    DATA = 2,
    PARITY = 3,
    STOP = 4;

reg [2:0] current_state, next_state;

wire [9:0] BIT_TRANSFER_PERIOD ;

assign BIT_TRANSFER_PERIOD = CLOCK_FREQ / BAUD_RATE; //baud rate - bit/s  -- timp pt bit
counter_dut #(
    .WIDTH(COUNTER_WIDTH)
) bit_data_counter (
    .data(data1),
    .load(load1),
    .updown(1'b0),
    .enable(enable1),
    .reset(reset),
    .clk(clk),
    .counter_o(cnt1),
    .ovf_o(ovf1)
);

counter_dut #(
    .WIDTH(COUNTER_WIDTH)
) clock_cycle (
    .data(BIT_TRANSFER_PERIOD),
    .load(load2),
    .updown(1'b0),
    .enable(enable2),
    .reset(reset),
    .clk(clk),
    .counter_o(cnt2),
    .ovf_o(ovf2)
);

// se prezice starea viitoare
always @* begin

    case (current_state)
      WAIT_TRANSMISSION: begin
        if (valid == 1 && ready == 1 ) begin
          next_state <= START;
        end
      end
      START: begin
        if (clock_cycle.ovf_o == 1)
          next_state <= DATA;
      end
      DATA: begin
        if (clock_cycle.ovf_o == 1 && bit_data_counter.ovf_o == 1)
          next_state <= PARITY;
      end
      PARITY: begin
        if (clock_cycle.ovf_o == 1 || PARITY == 0)
          next_state <= STOP;
      end
      STOP: begin
        if (clock_cycle.ovf_o == 1)
          next_state <= WAIT_TRANSMISSION;
      end
      default: current_state<=WAIT_TRANSMISSION;
    endcase
end

//circuitul se muta in starea viitoare
always @(posedge clk or posedge reset) begin
    if (reset) begin
      current_state <= WAIT_TRANSMISSION;
    end else begin
      current_state <= next_state;
    end
end    
//incarcare contor cicluri de ceas
always @(posedge clk or posedge reset) begin
    if(reset) begin
      clock_cycle.load <= 0;
    end else begin
      if( clock_cycle.load == 1 ) begin
        clock_cycle.load <= 0;
      end else begin
        if( ((next_state != current_state) && next_state != WAIT_TRANSMISSION) || (current_state == DATA && clock_cycle.ovf_o == 1))begin
          clock_cycle.load <= 1;
        end
      end
    end
end
//controlul contorului cicluri de ceas
always @(posedge clk or posedge reset) begin
    if(reset) begin
      clock_cycle.enable <= 0;
    end else begin
        if( current_state == WAIT_TRANSMISSION ) begin
        clock_cycle.enable <= 0;
      end else begin
        if( current_state != WAIT_TRANSMISSION ) begin
          clock_cycle.enable <= 1;
       end
      end
     end
end
//incarcare contorului de date
always @(posedge clk or posedge reset) begin
    if(reset) 
      bit_data_counter.load <= 0;
    else if(next_state != current_state && next_state == DATA) 
        bit_data_counter.load <= 1;
    else
        bit_data_counter.load <=0;
end
//controlul contorului de date
always @(posedge clk or posedge reset) begin
    if(reset) begin
      bit_data_counter.enable <= 0;
    end else begin
      if( bit_data_counter.enable == 1 ) begin
        bit_data_counter.enable <= 0;
      end else begin
        if( current_state == DATA && clock_cycle.ovf_o == 1) begin
          clock_cycle.enable <= 1;
        end
      end
    end
end
//bloc pt semnal ready
always @(posedge clk or posedge reset) begin
    if(reset) begin
      ready <= 1;
    end else begin
      if( current_state != WAIT_TRANSMISSION ) begin
        ready <= 0;
      end else begin
        ready <= 1;
      end
    end
end
//bloc pt semnal tx (transmisie)
always @(posedge clk or posedge reset) begin
    if(reset) begin
      tx <= 1;
    end else begin
      if(current_state == WAIT_TRANSMISSION) begin
        tx <= 1;
      end else begin
        if(current_state == START) begin
          tx <= 0;
        end else begin
          if (current_state == DATA) begin
            tx <= data[bit_data_counter.counter_o];
          end else begin
            if ( current_state == PARITY && PARITY_BIT == 1) begin
              tx <= (^data);
            end else begin
              if( current_state == STOP ) begin
                tx <= 1;
                end else begin
                tx<= 1'bx;
              end
            end
          end
        end
      end
    end
end
endmodule