`timescale 1ns / 1ps

module top(
    input clk
  , input rst
  , input int matrix1_size [0:1] // [x,y]
  , input int matrix1 [0:31][0:31]
  , input int matrix2_size [0:1] // [x,y] 
  , input int matrix2 [0:31][0:31]
  , input start
  , output busy
  , output int out_matrix [0:31][0:31]
    );
    
    
//    int ACT_X = matrix1_size[1];
//    int ACT_Y = matrix1_size[0];
    
//    int WEIGHT_X = matrix2_size[0];
//    int WEIGHT_Y = matrix2_size[1];
    
    localparam ACT_X = 27;
    localparam ACT_Y = 32;
    
    localparam WEIGHT_X = 27;
    localparam WEIGHT_Y = 16;
    
    localparam ACTIVATION_COUNT = 16; 
    localparam WEIGHT_COUNT = 16;
    
    
    localparam ARR_LINES_FOR_ONE_WEIGHT_LINE = WEIGHT_X/ACTIVATION_COUNT + (WEIGHT_X/ACTIVATION_COUNT)?1:0;
    localparam ACT_CALC_COUNT = (ACTIVATION_COUNT-1) + ARR_LINES_FOR_ONE_WEIGHT_LINE*ACT_Y;
    
    
    int systol_activation[0:ACTIVATION_COUNT-1];
    int systol_weight[0:WEIGHT_COUNT-1];
    int systol_result[0:WEIGHT_COUNT-1];
    logic weight_change;
    
    systol_array
    #(  .ACTIVATION_COUNT(ACTIVATION_COUNT), 
        .WEIGHT_COUNT(WEIGHT_COUNT))
    SYS_ARR (
    .clk(clk),
    .rst(rst),
    .activation(systol_activation),
    .weight(systol_weight),
    .weight_change(weight_change),
    .result(systol_result)
    );
    
    logic weight_fifo_full;
    logic weight_fifo_almost_full;
    logic weight_fifo_wr_en;
    logic weight_fifo_empty;
    logic weight_fifo_rd_en;
    logic weight_fifo_srst;
    
    logic [32*WEIGHT_COUNT-1:0] weight_fifo_din;
    logic [32*WEIGHT_COUNT-1:0] weight_fifo_dout;
    logic [3:0] weight_fifo_count;
    
    fifo_generator_0 weight_fifo(
    .full(weight_fifo_full)
  , .almost_full(weight_fifo_almost_full)
  , .din(weight_fifo_din)
  , .wr_en(weight_fifo_wr_en)
  , .empty(weight_fifo_empty)
  , .dout(weight_fifo_dout)
  , .rd_en(weight_fifo_rd_en)
  , .clk(clk)
  , .srst(weight_fifo_srst)
  , .data_count(weight_fifo_count)
    );
    
    logic activation_fifo_full;
    logic activation_fifo_almost_full;
    logic activation_fifo_wr_en;
    logic activation_fifo_empty;
    logic activation_fifo_rd_en;
    logic activation_fifo_srst;
    
    logic [32*ACTIVATION_COUNT-1:0] activation_fifo_din;
    logic [32*ACTIVATION_COUNT-1:0] activation_fifo_dout;
    logic [3:0] activation_fifo_count;
    
    fifo_generator_0 activation_fifo(
    .full(activation_fifo_full)
  , .almost_full(activation_fifo_almost_full)
  , .din(activation_fifo_din)
  , .wr_en(activation_fifo_wr_en)
  , .empty(activation_fifo_empty)
  , .dout(activation_fifo_dout)
  , .rd_en(activation_fifo_rd_en)
  , .clk(clk)
  , .srst(activation_fifo_srst)
  , .data_count(activation_fifo_count)
    );

    localparam FILL_SYSTOL = 2'd0;
    localparam CALC_SYSTOL = 2'd1;
    localparam IDLE = 2'd2;
   
    reg [1:0] state, next_state;
       
    logic [3:0] weight_fill_counter;
    int activation_calc_counter;
    
    int sum_result[0:WEIGHT_COUNT/ARR_LINES_FOR_ONE_WEIGHT_LINE-1];
    
    int out_line_ptr;
    int out_col_ptr;
    
    assign busy = state[0] | state[1];
    
    //SYSTOL ARRAY filling
    
    assign {>>{systol_weight}} = weight_fifo_dout;
    assign {>>{systol_activation}} = activation_fifo_dout;
     
    always @ (negedge clk) begin
        if(rst) begin
            weight_fill_counter <= 0;
            activation_calc_counter <= 0;
            weight_change <= 0;
        end
        else begin
            case(state)
                IDLE: begin
                    weight_change <= 0;
                    
                    weight_fill_counter <= 0;
                    activation_calc_counter <= 0;
                    weight_fifo_rd_en <= 0;
                    activation_fifo_rd_en <= 0;
                    
                    out_line_ptr <= 0;
                    out_col_ptr <= 0;
                end
                FILL_SYSTOL: begin 
                    activation_calc_counter <= 0;
                    weight_change <= 1;
                    
                    if(weight_fifo_empty == 0) begin
                        weight_fifo_rd_en <= 1;
                        weight_fill_counter <= weight_fill_counter+1;
                    end
                    else begin
                        weight_fifo_rd_en <= 0;
                    end  
                end
                CALC_SYSTOL: begin
                    weight_fill_counter <= 0;
                    weight_change <= 0;
                
                    if(activation_fifo_empty == 0) begin
                       activation_fifo_rd_en <= 1;
                       activation_calc_counter <= activation_calc_counter+1;
                    end 
                    else begin
                        activation_fifo_rd_en <= 0;
                    end
                    
                    if(activation_calc_counter >= ACTIVATION_COUNT) begin
                        for(int z=0;z<WEIGHT_COUNT/ARR_LINES_FOR_ONE_WEIGHT_LINE; z++) begin
                            if(activation_calc_counter%ARR_LINES_FOR_ONE_WEIGHT_LINE == 0) begin
                                sum_result[z] <= systol_result[z*ARR_LINES_FOR_ONE_WEIGHT_LINE];
                            end
                            else begin
                                if(z < (activation_calc_counter-ACTIVATION_COUNT)/2+1)
                                    out_matrix[out_line_ptr+z][out_col_ptr] <= sum_result[z] + systol_result[z*ARR_LINES_FOR_ONE_WEIGHT_LINE + activation_calc_counter%ARR_LINES_FOR_ONE_WEIGHT_LINE];
                                    out_line_ptr <= out_col_ptr+1; 
                                    out_col_ptr <= out_col_ptr+1; 
                            end
                        end
                    end
                end
            endcase 
        end
    end
    
    //FSM
    
    always @ (posedge clk) begin
        state <= next_state;
    end 
    
    always_comb begin
        case (state)
            IDLE: begin
                if(start) begin
                    next_state = FILL_SYSTOL;
                end
            end
            FILL_SYSTOL:      begin
                if(weight_fill_counter == ACTIVATION_COUNT-1) begin
                    next_state = CALC_SYSTOL;
                end
            end
            CALC_SYSTOL:      begin
                if(activation_calc_counter == ACT_CALC_COUNT-1) begin
                    next_state = FILL_SYSTOL;
                end
            end
            default: next_state = IDLE;
        endcase
    end
  
    //FIFO filling
    
    int weight_line_offset;
    int weight_col_offset;
    
    int activation_line_offset;
    int activation_col_offset;
  
    always@(negedge clk) begin
        if(rst | (state == IDLE)) begin
            weight_fifo_srst <= 1;
            weight_fifo_wr_en <= 0;
            weight_fifo_rd_en <= 0;
            
            weight_fifo_srst <= 1;
            weight_fifo_wr_en <= 0;
            weight_fifo_rd_en <= 0;
            
            weight_line_offset <= 0;
            weight_col_offset <= 0;
            
            activation_line_offset <= 0;
            activation_col_offset <= 0;
        end
        else begin
            weight_fifo_srst <= 0;
            activation_fifo_srst <= 0;
            
            if(weight_fifo_almost_full == 0) begin
                if(weight_col_offset < WEIGHT_Y) begin
                    
                    for(int n=0; n<ARR_LINES_FOR_ONE_WEIGHT_LINE; n++) begin
                        for(int i=0;i<WEIGHT_COUNT/ARR_LINES_FOR_ONE_WEIGHT_LINE;i++) begin
                            weight_fifo_din[(ARR_LINES_FOR_ONE_WEIGHT_LINE*i+n)*32 +: 32] <= matrix2[i+weight_col_offset][n*ACTIVATION_COUNT+weight_line_offset];
                        end
                    end
                    weight_fifo_wr_en <= 1;
                    
                    weight_line_offset <= weight_line_offset+1;
                    
                    if(weight_line_offset == ACTIVATION_COUNT) begin
                        weight_line_offset <= 0;
                        weight_col_offset <= weight_col_offset+WEIGHT_COUNT/ARR_LINES_FOR_ONE_WEIGHT_LINE; 
                    end
                end
                
            end
            else begin
                weight_fifo_wr_en <= 0;
            end
            
            if(activation_fifo_almost_full == 0) begin
                if(activation_col_offset < ACT_Y) begin

                    for(int j=0;j<ACTIVATION_COUNT;j++) begin
                        activation_fifo_din[j*32 +: 32] <= matrix1[j+activation_line_offset][activation_col_offset];
                    end
                    activation_fifo_wr_en <= 1;
                    
                    activation_line_offset <= activation_line_offset+ACTIVATION_COUNT;
                    
                    if(activation_line_offset > ACT_X) begin
                        activation_line_offset <= 0;
                        activation_col_offset <= activation_col_offset+1;
                    end
                    
                end
            end
            else begin
                activation_fifo_wr_en <= 0;
            end

        end
    end

endmodule
