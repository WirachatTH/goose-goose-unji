`timescale 1ns / 1ps

module Clk_div(
    input Clk_In,
    input Reset,
    output Clk_Out
    );
    
    reg [19:0] Counter_r;
    reg Clk_r;
    
    parameter COUNT_MAX = 833_333 - 1;
    
    always @(posedge Clk_In) begin
        if (!Reset) begin
            Clk_r <= 0;
            Counter_r <= 0;
        end else begin
            if (Counter_r == COUNT_MAX) begin
              Clk_r <= ~Clk_r;
              Counter_r <= 0;
            end else begin
              Counter_r <= Counter_r + 1;
            end
        end
    end
    
    assign Clk_Out = Clk_r;
endmodule
