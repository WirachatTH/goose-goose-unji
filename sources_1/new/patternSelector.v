`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: patternSelector
// Description: Selects lane patterns based on weighted randomness.
//              Expanded patterns with ~4-5 empty slots per tier.
//////////////////////////////////////////////////////////////////////////////////

module patternSelector (
    input GameTick,
    input [15:0] randomize_value, // เลขสุ่ม 16-bit จาก LFSR
    input select_enable,          // สัญญาณ Trigger จาก Obj_Manager
    output reg [4:0] new_pattern
);
    // กำหนด Range Boundaries (ฐาน 65536)
    parameter P_LOW_MAX = 16'd29491; // 45%
    parameter P_MED_MAX = 16'd52428; // 35%
    // P_HIGH_MAX คือที่เหลือ (20%)

    wire [15:0] Random_Group = randomize_value;
    wire [3:0] Random_Sub = randomize_value[3:0]; // 0-15

    reg [4:0] selected_pattern_reg;
    
    // ตรรกะการเลือกกลุ่ม (Weighted Group Selection)
    wire [1:0] group_select;
    assign group_select = (Random_Group <= P_LOW_MAX) ? 2'b00 :
                          (Random_Group <= P_MED_MAX) ? 2'b01 :
                          2'b10;

    // ตรรกะการสุ่มรูปแบบ (Pattern Selection Logic)
    always @(*) begin
        case (group_select)
            // ------------------------------------------------------
            // P-Low (45%): ง่าย (1-2 เลน)
            // ------------------------------------------------------
            2'b00: begin 
                case (Random_Sub)
                    // แบบ 1 เลน (Basic)
                    4'd0: selected_pattern_reg = 5'b00001; // เลน 1
                    4'd1: selected_pattern_reg = 5'b00010; // เลน 2
                    4'd2: selected_pattern_reg = 5'b00100; // เลน 3
                    4'd3: selected_pattern_reg = 5'b01000; // เลน 4
                    4'd4: selected_pattern_reg = 5'b10000; // เลน 5
                    
                    // แบบ 2 เลน (คู่)
                    4'd5: selected_pattern_reg = 5'b10001; // ขอบซ้าย-ขวา
                    4'd6: selected_pattern_reg = 5'b01010; // คู่เลน 2-4
                    4'd7: selected_pattern_reg = 5'b00110; // คู่ชิด 2-3
                    4'd8: selected_pattern_reg = 5'b01100; // คู่ชิด 3-4
                    4'd9: selected_pattern_reg = 5'b11000; // คู่ชิด 4-5
                    4'd10: selected_pattern_reg = 5'b00011; // คู่ชิด 1-2

                    // 5 เคสที่เหลือ (11-15) = ว่าง (Empty)
                    default: selected_pattern_reg = 5'b00000; 
                endcase
            end

            // ------------------------------------------------------
            // P-Med (35%): ปานกลาง (2-3 เลน)
            // ------------------------------------------------------
            2'b01: begin 
                case (Random_Sub)
                    // แบบ 2 เลน (กระจาย)
                    4'd0: selected_pattern_reg = 5'b10100; // 3, 5
                    4'd1: selected_pattern_reg = 5'b00101; // 1, 3
                    
                    // แบบ 3 เลน (กำแพงเล็ก)
                    4'd2: selected_pattern_reg = 5'b11100; // 3,4,5 (กำแพงขวา)
                    4'd3: selected_pattern_reg = 5'b00111; // 1,2,3 (กำแพงซ้าย)
                    4'd4: selected_pattern_reg = 5'b01110; // 2,3,4 (กำแพงกลาง)
                    4'd5: selected_pattern_reg = 5'b10101; // 1,3,5 (ฟันปลา)
                    4'd6: selected_pattern_reg = 5'b01011; // 1,2,4 (เว้น 3,5)
                    4'd7: selected_pattern_reg = 5'b11010; // 2,4,5 (เว้น 1,3)
                    4'd8: selected_pattern_reg = 5'b10011; // 1,2,5 (เว้น 3,4)
                    4'd9: selected_pattern_reg = 5'b11001; // 1,4,5 (เว้น 2,3)
                    
                    // แบบ 3 เลน (กระจาย)
                    4'd10: selected_pattern_reg = 5'b10110; // 2,3,5

                    // 5 เคสที่เหลือ (11-15) = ว่าง (Empty)
                    default: selected_pattern_reg = 5'b00000;
                endcase
            end

            // ------------------------------------------------------
            // P-High (20%): ยาก (4-5 เลน)
            // ------------------------------------------------------
            2'b10: begin 
                case (Random_Sub)
                    // แบบ 4 เลน (เหลือช่องเดียวให้รอด)
                    4'd0: selected_pattern_reg = 5'b11110; // รอดเลน 1
                    4'd1: selected_pattern_reg = 5'b11101; // รอดเลน 2
                    4'd2: selected_pattern_reg = 5'b11011; // รอดเลน 3 (กลาง)
                    4'd3: selected_pattern_reg = 5'b10111; // รอดเลน 4
                    4'd4: selected_pattern_reg = 5'b01111; // รอดเลน 5
                    
                    // ซ้ำรูปแบบเพื่อเพิ่มโอกาสเกิด
                    4'd5: selected_pattern_reg = 5'b11110; // รอดเลน 1
                    4'd6: selected_pattern_reg = 5'b10111; // รอดเลน 5
                    4'd7: selected_pattern_reg = 5'b11011; // รอดเลน 3
                    4'd8: selected_pattern_reg = 5'b11101; // รอดเลน 3
                    4'd9: selected_pattern_reg = 5'b11110; // รอดเลน 3
                    
                    // แบบ 5 เลน (กำแพงตัน - ต้องยิงหรือชน)
                    4'd10: selected_pattern_reg = 5'b11111; // เต็มทุกเลน

                    // 5 เคสที่เหลือ (11-15) = ว่าง (Empty)
                    default: selected_pattern_reg = 5'b00000;
                endcase
            end
            
            default: selected_pattern_reg = 5'b00000;
        endcase
    end
    
    always @(posedge GameTick) begin
        if (select_enable) begin
            new_pattern <= selected_pattern_reg;
        end
    end

endmodule