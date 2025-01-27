module D_FlipFlop(input D,clk,rst,output reg Q );
    always @(posedge clk or negedge rst) begin
        if(!rst)
            Q<=0;
        else
            Q<=D;
    end
endmodule
module Johnson_counter #(parameter N=4)(input rst,clk,output [N-1:0]Q);
    genvar ii;
    generate
        for (ii=0;ii<N;ii=ii+1) begin
            if(ii==0) begin
                D_FlipFlop d(~Q[N-1],clk,rst,Q[ii]);
            end
            else begin
                D_FlipFlop d(Q[ii-1],clk,rst,Q[ii]);
            end
        end
    endgenerate 
endmodule
module TB;
    parameter N=32;
    reg rst;
    reg clk;
    wire [N-1:0]Q;
    always begin
        #5 clk=~clk;
    end
    Johnson_counter #(.N(N)) sample (rst,clk,Q);
    initial begin
        clk=0;
        rst<=0;
        #2 rst<=1;
        #500 $finish;
    end
    initial begin
        $monitor("%b", Q);
    end
    initial begin
        $dumpfile("Johnson_counter.vcd");
        $dumpvars(0,TB);
    end
endmodule
