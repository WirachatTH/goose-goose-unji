`timescale 1ns / 1ps

module patternSelector (
    input GameTick,
    input [15:0] randomize_value, //เลขสุ่ม 16-bit จาก randomizer.v
    input select_enable,          //สัญญาณ Trigger จาก objManager.v
    output reg [4:0] new_pattern
);
    parameter P_LOW_MAX = 16'd29491; //45%
    parameter P_MED_MAX = 16'd52428; //35%
    wire [15:0] Random_Group = randomize_value;
    wire [3:0] Random_Sub = randomize_value[3:0]; //0-15

    reg [4:0] selected_pattern_reg;
    
    //Weighted Group Selection
    wire [1:0] group_select;
    assign group_select = (Random_Group <= P_LOW_MAX) ? 2'b00 :
                          (Random_Group <= P_MED_MAX) ? 2'b01 :
                          2'b10;

    //Pattern Selection Logic
    always @(*) begin
        case (group_select)
            //45% 1 - 2 เลน
            2'b00: begin 
                case (Random_Sub)
                    //แบบ 1 เลน
                    4'd0: selected_pattern_reg = 5'b00001;
                    4'd1: selected_pattern_reg = 5'b00010;
                    4'd2: selected_pattern_reg = 5'b00100;
                    4'd3: selected_pattern_reg = 5'b01000;
                    4'd4: selected_pattern_reg = 5'b10000;
                    
                    //แบบ 2 เลน
                    4'd5: selected_pattern_reg = 5'b10001;
                    4'd6: selected_pattern_reg = 5'b01010;
                    4'd7: selected_pattern_reg = 5'b00110;
                    4'd8: selected_pattern_reg = 5'b01100;
                    4'd9: selected_pattern_reg = 5'b11000;
                    4'd10: selected_pattern_reg = 5'b00011;
                    4'd11: selected_pattern_reg = 5'b10010;
                    4'd12: selected_pattern_reg = 5'b01001;

                    //ว่าง
                    default: selected_pattern_reg = 5'b00000; 
                endcase
            end

            //35% 2 - 3 เลน
            2'b01: begin 
                case (Random_Sub)
                    //แบบ 2 เลน
                    4'd0: selected_pattern_reg = 5'b10100;
                    4'd1: selected_pattern_reg = 5'b00101;
                    
                    //แบบ 3 เลน
                    4'd2: selected_pattern_reg = 5'b11100;
                    4'd3: selected_pattern_reg = 5'b00111;
                    4'd4: selected_pattern_reg = 5'b01110;
                    4'd5: selected_pattern_reg = 5'b10101;
                    4'd6: selected_pattern_reg = 5'b01011;
                    4'd7: selected_pattern_reg = 5'b11010;
                    4'd8: selected_pattern_reg = 5'b10011;
                    4'd9: selected_pattern_reg = 5'b11001;
                    4'd10: selected_pattern_reg = 5'b10110;

                    //ว่าง
                    default: selected_pattern_reg = 5'b00000;
                endcase
            end

            //25% 4 - 5 เลน
            2'b10: begin 
                case (Random_Sub)
                    //แบบ 4 เลน
                    4'd0: selected_pattern_reg = 5'b11110;
                    4'd1: selected_pattern_reg = 5'b11101;
                    4'd2: selected_pattern_reg = 5'b11011;
                    4'd3: selected_pattern_reg = 5'b10111;
                    4'd4: selected_pattern_reg = 5'b01111;
                    4'd5: selected_pattern_reg = 5'b11110;
                    4'd6: selected_pattern_reg = 5'b10111;
                    4'd7: selected_pattern_reg = 5'b11011;
                    4'd8: selected_pattern_reg = 5'b11101;
                    4'd9: selected_pattern_reg = 5'b11110;
                    
                    //แบบ 5 เลน บังคับให้ยิงปืน
                    4'd10: selected_pattern_reg = 5'b11111;
                    4'd11: selected_pattern_reg = 5'b11111;

                    //ว่าง
                    default: selected_pattern_reg = 5'b00000;
                endcase
            end
            //ว่าง
            default: selected_pattern_reg = 5'b00000;
        endcase
    end
    
    always @(posedge GameTick) begin
        if (select_enable) begin
            new_pattern <= selected_pattern_reg;
        end
    end

endmodule