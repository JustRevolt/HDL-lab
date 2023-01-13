`timescale 1ns / 1ps

module systol_array
    #(  parameter ACTIVATION_COUNT = 16, 
        parameter WEIGHT_COUNT = 16)
    (
    input clk,
    input rst,
    input int activation [0:ACTIVATION_COUNT-1],
    input int weight [WEIGHT_COUNT-1:0],
    input weight_change,
    output int result [WEIGHT_COUNT-1:0]
    );
    
    
    /*
    x   4   3   2   1   0
                            0
                            1
                            2
                            3
                            4
                            x
    */
    
    
    localparam FILL_STAND = 2'b0;
    localparam CALC =       2'b1;
   
    reg state, next_state;
    
    always @ (posedge clk) begin
        state <= next_state;
    end 
    
    always_comb begin
        case (state)
            FILL_STAND:      begin
                if(weight_change) next_state = FILL_STAND;
                else next_state = CALC;
            end
            CALC:       begin
                if(weight_change) next_state = FILL_STAND;
                else next_state = CALC;
            end
            default: next_state = CALC;
        endcase
    end
    
    
    int mac_res [0:WEIGHT_COUNT-1][0:ACTIVATION_COUNT-1];
    int weight_reg [0:WEIGHT_COUNT-1][0:ACTIVATION_COUNT-1];
    int activation_reg [0:WEIGHT_COUNT-1][0:ACTIVATION_COUNT-1];
    
    
    genvar k;
    generate
        for(k=0; k<WEIGHT_COUNT; k++) begin
            assign result[k] = mac_res[k][ACTIVATION_COUNT-1];
        end
    endgenerate
    
    
    always@(posedge clk)
        if (rst) begin
            state <= CALC;
        end
        else begin
            case (state)
            FILL_STAND:      begin
                for(int j=0; j<WEIGHT_COUNT; j++) weight_reg[j][0] <= weight[j];
                for(int i=1; i<ACTIVATION_COUNT; i++) begin
                    for(int j=0; j<WEIGHT_COUNT; j++) begin
                        weight_reg[j][i] <= weight_reg[j][i-1];
                    end
                end
            end
            CALC:       begin
                for(int i=0; i<ACTIVATION_COUNT; i++) activation_reg[0][i] <= activation[i];
                for(int j=1; j<WEIGHT_COUNT; j++) begin
                    for(int i=0; i<ACTIVATION_COUNT; i++) begin
                        activation_reg[j][i] <= activation_reg[j-1][i];
                    end
                end
                
                for(int j=0; j<WEIGHT_COUNT; j++) mac_res[j][0] <= weight_reg[j][0]*activation_reg[j][0];
                for(int i=1; i<ACTIVATION_COUNT; i++) begin
                    for(int j=0; j<WEIGHT_COUNT; j++) begin
                        mac_res[j][i] <= weight_reg[j][i]*activation_reg[j][i]+mac_res[j][i-1];
                    end
                end
            end
        endcase
        end
    
endmodule
