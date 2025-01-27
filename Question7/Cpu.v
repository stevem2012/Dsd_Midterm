module RegisterFile (
    input wire clk,
    input wire [1:0] read_reg1, read_reg2, write_reg1,write_reg2,
    input wire [511:0] write_data1,write_data2,
    input wire reg_write_enable1,reg_write_enable2,
    output reg [511:0] read_data1, read_data2
);
    reg [511:0] registers [0:3];
    always @(posedge clk) begin
                if(reg_write_enable1)
                    registers[write_reg1] <= write_data1;
                if(reg_write_enable2)
                    registers[write_reg2] <= write_data2;
    end
    always @(*) begin
        read_data1 = registers[read_reg1];
        read_data2 = registers[read_reg2];
    end
endmodule
module ArithmeticUnit (
    input wire [511:0] A1, A2,
    input wire [1:0] operation, // 00: no-op, 01: addition, 10: multiplication
    output reg [511:0] A3, A4
);
    always @(*) begin
        case (operation)
            2'b10: begin
                // A4=512'b0;
                {A4, A3} = A1 + A2;
            end
            2'b11: begin
                {A4, A3} = A1 * A2;
            end
            default: begin
                A3 = 0;
                A4 = 0;
            end
        endcase
    end
endmodule
module Memory (
    input wire clk,
    input wire mem_write_enable,
    input wire [8:0] mem_addr,
    input wire [511:0] mem_write_data,
    output reg [511:0] mem_read_data
);
    reg [31:0] memory [0:511];

    integer i;

    always @(posedge clk) begin
        if (mem_write_enable) begin
            for (i = 0; i < 16; i = i + 1) begin
                memory[mem_addr + i] <= mem_write_data[(i*32) +: 32];
            end
        end
    end

    always @(*) begin
        for (i = 0; i < 16; i = i + 1) begin
            mem_read_data[(i*32) +: 32] = memory[mem_addr + i];
        end
    end
endmodule
 module Processor (
    input wire clk,
    input wire [1:0] instruction, // 00: load, 01: store, 10: add, 11: multiply 
    input wire [1:0] reg_select_read1, reg_select_read2, reg_select_write1, reg_select_write2,
    input wire [8:0] mem_addr,
    input wire [511:0] mem_write_data, // input of processor
    input wire control,
    input wire reg_write_enable1,
    input wire reg_write_enable2,
    output wire [511:0] A1, A2, A3, A4 // for checking content of A!, A2, A3, A4
);
    wire [511:0] alu_result1, alu_result2;
    wire [511:0] reg_read_data1, reg_read_data2;
    wire [511:0] mem_read_data;
    RegisterFile rf (
        .clk(clk),
        .read_reg1(reg_select_read1),
        .read_reg2(reg_select_read2),
        .write_reg1(reg_select_write1),
        .write_reg2(reg_select_write2),
        .write_data1((instruction == 2'b00) ? mem_read_data : alu_result1),
        .write_data2((instruction == 2'b00) ? 512'bz : alu_result2),
        .reg_write_enable1(reg_write_enable1),
        .reg_write_enable2(reg_write_enable2),
        .read_data1(reg_read_data1),
        .read_data2(reg_read_data2)
    );
    ArithmeticUnit alu (
        .A1(reg_read_data1),
        .A2(reg_read_data2),
        .operation(instruction[1:0]),
        .A3(alu_result1),
        .A4(alu_result2)
    );
    Memory mem (
        .clk(clk),
        .mem_write_enable(instruction == 2'b01),
        .mem_addr(mem_addr),
        .mem_write_data((control==1)? mem_write_data:reg_read_data1),
        .mem_read_data(mem_read_data)
    );
    assign A1 = reg_read_data1;
    assign A2 = reg_read_data2;
    assign A3 = alu_result1;
    assign A4 = alu_result2;
    
endmodule
module TestBench1;
    reg clk;
    reg [1:0] instruction;
    reg [1:0] reg_select_read1, reg_select_read2, reg_select_write1, reg_select_write2;
    reg [8:0] mem_addr;
    reg [511:0] mem_write_data;
    wire [511:0] A1, A2, A3, A4;
    reg control;
    reg reg_write_enable1;
    reg reg_write_enable2;
    Processor processor(
        .clk(clk),
        .instruction(instruction),
        .reg_select_read1(reg_select_read1),
        .reg_select_read2(reg_select_read2),
        .reg_select_write1(reg_select_write1),
        .reg_select_write2(reg_select_write2),
        .mem_addr(mem_addr),
        .mem_write_data(mem_write_data),
        .control(control),
        .reg_write_enable1(reg_write_enable1),
        .reg_write_enable2(reg_write_enable2),
        .A1(A1),
        .A2(A2),
        .A3(A3),
        .A4(A4)
    );

    always 
        #5 clk=~clk; 

    initial begin 
    reg_write_enable1 = 0;
    reg_write_enable2 = 0;
    clk = 0;
    instruction = 2'b01;
    mem_addr = 9'b0;
    control = 1;
    mem_write_data = 512'b10; // 2 in binary
    #10
    mem_addr = 9'b010000000; // 128 in binary
    mem_write_data = 512'b100; // 4 in binary
    #10  
    control = 0;
    instruction = 2'b00;
    mem_addr = 9'b0;
    reg_select_write1 = 2'b00;
    reg_write_enable1 = 1;
    #10 
    mem_addr = 9'b010000000;
    reg_select_write1 = 2'b01;
    #10
    reg_write_enable1 = 0;
    reg_select_read1 = 2'b00;
    reg_select_read2 = 2'b01;
    #10
    instruction = 2'b10; // add
    #50
    $display("A2= %d\n A1= %d", A2, A1);
    $display("A4= %d\n A3= %d", A4, A3);
    reg_select_write1=2'b10;
    reg_select_write2=2'b11;
    reg_write_enable1=1;
    reg_write_enable2=1;
    #10
    instruction=2'b01;
    reg_select_read1=2'b10;
    mem_addr=9'b0;
    #10
    reg_select_read1=2'b11;
    mem_addr = 9'b010000000;
    #10 
    instruction = 2'b00;
    mem_addr = 9'b0;
    reg_select_write1 = 2'b00;
    reg_write_enable1 = 1;
    #10 
    mem_addr = 9'b010000000;
    reg_select_write1 = 2'b01;
    #10
    reg_write_enable1 = 0;
    reg_select_read1 = 2'b00;
    reg_select_read2 = 2'b01;
    #10
    $display("A1= %d\n A2= %d", A1, A2);
    #20 $finish;
    end
endmodule
module TestBench2;
    reg clk;
    reg [1:0] instruction;
    reg [1:0] reg_select_read1, reg_select_read2, reg_select_write1, reg_select_write2;
    reg [8:0] mem_addr;
    reg [511:0] mem_write_data;
    wire [511:0] A1, A2, A3, A4;
    reg control;
    reg reg_write_enable1;
    reg reg_write_enable2;
    Processor processor(
        .clk(clk),
        .instruction(instruction),
        .reg_select_read1(reg_select_read1),
        .reg_select_read2(reg_select_read2),
        .reg_select_write1(reg_select_write1),
        .reg_select_write2(reg_select_write2),
        .mem_addr(mem_addr),
        .mem_write_data(mem_write_data),
        .control(control),
        .reg_write_enable1(reg_write_enable1),
        .reg_write_enable2(reg_write_enable2),
        .A1(A1),
        .A2(A2),
        .A3(A3),
        .A4(A4)
    );

    always 
        #5 clk=~clk; 

    initial begin 
    reg_write_enable1 = 0;
    reg_write_enable2 = 0;
    clk = 0;
    instruction = 2'b01;
    mem_addr = 9'b0;
    control = 1;
    mem_write_data = {1'b0,{511{1'b1}}};
    #10
    mem_addr = 9'b010000000; 
    mem_write_data = {512{1'b1}}; 
    #10  
    control = 0;
    instruction = 2'b00;
    mem_addr = 9'b0;
    reg_select_write1 = 2'b00;
    reg_write_enable1 = 1;
    #10 
    mem_addr = 9'b010000000;
    reg_select_write1 = 2'b01;
    #10
    reg_write_enable1 = 0;
    reg_select_read1 = 2'b00;
    reg_select_read2 = 2'b01;
    #10
    instruction = 2'b11; // multiply 
    #50
    $display("A2= %b\n A1= %b", A2, A1);
    $display("A4= %b\n A3= %b", A4, A3);
    #20 $finish;
    end
endmodule
module TestBench5;
    reg clk;
    reg [1:0] instruction;
    reg [1:0] reg_select_read1, reg_select_read2, reg_select_write1, reg_select_write2;
    reg [8:0] mem_addr;
    reg [511:0] mem_write_data;
    wire [511:0] A1, A2, A3, A4;
    reg control;
    reg reg_write_enable1;
    reg reg_write_enable2;
    Processor processor(
        .clk(clk),
        .instruction(instruction),
        .reg_select_read1(reg_select_read1),
        .reg_select_read2(reg_select_read2),
        .reg_select_write1(reg_select_write1),
        .reg_select_write2(reg_select_write2),
        .mem_addr(mem_addr),
        .mem_write_data(mem_write_data),
        .control(control),
        .reg_write_enable1(reg_write_enable1),
        .reg_write_enable2(reg_write_enable2),
        .A1(A1),
        .A2(A2),
        .A3(A3),
        .A4(A4)
    );

    always 
        #5 clk=~clk; 

    initial begin 
    reg_write_enable1 = 0;
    reg_write_enable2 = 0;
    clk = 0;
    instruction = 2'b01;
    mem_addr = 9'b0;
    control = 1;
    mem_write_data = {1'b0,{511{1'b1}}};
    #10
    mem_addr = 9'b010000000; 
    mem_write_data = -{1'b0,{511{1'b1}}}; 
    #10  
    control = 0;
    instruction = 2'b00;
    mem_addr = 9'b0;
    reg_select_write1 = 2'b00;
    reg_write_enable1 = 1;
    #10 
    mem_addr = 9'b010000000;
    reg_select_write1 = 2'b01;
    #10
    reg_write_enable1 = 0;
    reg_select_read1 = 2'b00;
    reg_select_read2 = 2'b01;
    #10
    instruction = 2'b10; // add
    #50
    $display("A2= %b\n A1= %b", A2, A1);
    $display("A4= %b\n A3= %b", A4, A3);
    #20 $finish;
    end
endmodule
module TestBench3;
    reg clk;
    reg [1:0] instruction;
    reg [1:0] reg_select_read1, reg_select_read2, reg_select_write1, reg_select_write2;
    reg [8:0] mem_addr;
    reg [511:0] mem_write_data;
    wire [511:0] A1, A2, A3, A4;
    reg control;
    reg reg_write_enable1;
    reg reg_write_enable2;
    Processor processor(
        .clk(clk),
        .instruction(instruction),
        .reg_select_read1(reg_select_read1),
        .reg_select_read2(reg_select_read2),
        .reg_select_write1(reg_select_write1),
        .reg_select_write2(reg_select_write2),
        .mem_addr(mem_addr),
        .mem_write_data(mem_write_data),
        .control(control),
        .reg_write_enable1(reg_write_enable1),
        .reg_write_enable2(reg_write_enable2),
        .A1(A1),
        .A2(A2),
        .A3(A3),
        .A4(A4)
    );

    always 
        #5 clk=~clk; 

    initial begin 
    reg_write_enable1 = 0;
    reg_write_enable2 = 0;
    clk = 0;
    instruction = 2'b01;
    mem_addr = 9'b0;
    control = 1;
    mem_write_data = 512'd10;
    #10
    mem_addr = 9'b010000000; 
    mem_write_data = 512'd100; 
    #10  
    control = 0;
    instruction = 2'b00;
    mem_addr = 9'b0;
    reg_select_write1 = 2'b00;
    reg_write_enable1 = 1;
    #10 
    mem_addr = 9'b010000000;
    reg_select_write1 = 2'b01;
    #10
    reg_write_enable1 = 0;
    reg_select_read1 = 2'b00;
    reg_select_read2 = 2'b01;
    #10
    instruction = 2'b11; // multiply 
    #50
    $display("A2= %d\n A1= %d", A2, A1);
    $display("A4= %d\n A3= %d", A4, A3);
    #20 $finish;
    end
endmodule
module TestBench4;
    reg clk;
    reg [1:0] instruction;
    reg [1:0] reg_select_read1, reg_select_read2, reg_select_write1, reg_select_write2;
    reg [8:0] mem_addr;
    reg [511:0] mem_write_data;
    wire [511:0] A1, A2, A3, A4;
    reg control;
    reg reg_write_enable1;
    reg reg_write_enable2;
    Processor processor(
        .clk(clk),
        .instruction(instruction),
        .reg_select_read1(reg_select_read1),
        .reg_select_read2(reg_select_read2),
        .reg_select_write1(reg_select_write1),
        .reg_select_write2(reg_select_write2),
        .mem_addr(mem_addr),
        .mem_write_data(mem_write_data),
        .control(control),
        .reg_write_enable1(reg_write_enable1),
        .reg_write_enable2(reg_write_enable2),
        .A1(A1),
        .A2(A2),
        .A3(A3),
        .A4(A4)
    );

    always 
        #5 clk=~clk; 

    initial begin 
    reg_write_enable1 = 0;
    reg_write_enable2 = 0;
    clk = 0;
    instruction = 2'b01;
    mem_addr = 9'b0;
    control = 1;
    mem_write_data = {512{1'b1}};
    #10
    mem_addr = 9'b010000000; 
    mem_write_data = 512'b0; 
    #10  
    control = 0;
    instruction = 2'b00;
    mem_addr = 9'b0;
    reg_select_write1 = 2'b00;
    reg_write_enable1 = 1;
    #10 
    mem_addr = 9'b010000000;
    reg_select_write1 = 2'b01;
    #10
    reg_write_enable1 = 0;
    reg_select_read1 = 2'b00;
    reg_select_read2 = 2'b01;
    #10
    instruction = 2'b11; // multiply 
    #50
    $display("A2= %b\n A1= %b", A2, A1);
    $display("A4= %b\n A3= %b", A4, A3);
    #20 $finish;
    end
endmodule
