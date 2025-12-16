`timescale 1ns / 1ps

module InputDebounce(
    input Reset,
    input Clk_In,
    input Btn_In,
    output Btn_Out
    );
    
    parameter COUNT_MAX = 500_000 - 1;
    reg [18:0] Counter_r;
    reg Btn_State_r;
    reg Btn_Out_r;
    
    always @(posedge Clk_In) begin
        if (!Reset) begin
            Counter_r <= 0;
            Btn_State_r <= 0;
            Btn_Out_r <= 0;
        end else begin
            if (Btn_In != Btn_State_r) begin
                Counter_r <= 0;
                Btn_State_r <= Btn_In;
            end else begin
                if (Counter_r != COUNT_MAX) begin
                    Counter_r <= Counter_r + 1;
                end else begin
                    Btn_Out_r <= Btn_State_r;
                end
            end
        end
    end
    
    assign Btn_Out = Btn_Out_r;
endmodule
