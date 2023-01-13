`timescale 1ns / 1ps

module tb();

logic clk;
logic rst;

logic start;
logic busy;

int matrix1_size [0:1];
int matrix2_size [0:1];

int matrix1 [0:31][0:31];
int matrix2 [0:31][0:31];

int out_matrix [0:31][0:31];

top top(
    .clk(clk)
  , .rst(rst)
  , .matrix1_size(matrix1_size)
  , .matrix1(matrix1)  
  , .matrix2_size(matrix2_size)
  , .matrix2(matrix2)
  , .start(start)
  , .busy(busy)
  , .out_matrix(out_matrix)
);


always #10 clk=~clk;

initial begin
    clk=0;
    rst=1;
    
    #50
    rst=0;
    
    #50
    for(int i=0; i<32; i++) begin
        for(int j=0; j<32; j++) begin
            matrix1[i][j] = 0;
            matrix2[i][j] = 0;
        end
    end
    
    matrix1_size[0] = 32;
    matrix1_size[1] = 27;
    
    matrix2_size[0] = 27;
    matrix2_size[1] = 16;
    
    for(int i=0; i<matrix1_size[0]; i++) begin
        for(int j=0; j<matrix1_size[1]; j++) begin
            matrix1[i][j] <= $urandom_range(50, 0);
        end
    end
    
    for(int i=0; i<matrix2_size[0]; i++) begin
        for(int j=0; j<matrix2_size[1]; j++) begin
            matrix2[i][j] <= $urandom_range(50, 0);
        end
    end
    
    start <= 1;
    #50
    start <= 0;
    
    while(busy == 1) begin
        #1000;
    end
    
    $stop;
end

endmodule
