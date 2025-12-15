`timescale 1ns / 1ps

module FontMapper(
    input [7:0] char_code,    // รหัส ASCII ที่ต้องการวาด
    input is_small_font,      // 0 = แถว Y=150 (ปกติ), 1 = แถว Y=158 (เล็ก)
    
    output reg [9:0] o_sprite_x, 
    output reg [9:0] o_sprite_y
    );

    // ==========================================
    // CONFIG: ขนาดและตำแหน่ง (ตามที่คุณระบุ)
    // ==========================================
    parameter CHAR_W = 5;
    parameter CHAR_H = 7;

    parameter ROW_LOWER_Y = 132;   // a - z
    parameter ROW_UPPER_Y = 141;   // A - Z
    parameter ROW_NUM1_Y  = 150;   // 1-0... ปกติ
    parameter ROW_NUM2_Y  = 158;   // 1-0... เล็ก

    always @(*) begin
        // Default values
        o_sprite_x = 0;
        o_sprite_y = 0;

        // --------------------------------------------------
        // 1. ตัวพิมพ์เล็ก (a-z) -> Y = 132
        // --------------------------------------------------
        if (char_code >= "a" && char_code <= "z") begin
            o_sprite_y = ROW_LOWER_Y;
            // a=0, b=5, c=10...
            o_sprite_x = (char_code - "a") * CHAR_W;
        end
        
        // --------------------------------------------------
        // 2. ตัวพิมพ์ใหญ่ (A-Z) -> Y = 141
        // --------------------------------------------------
        else if (char_code >= "A" && char_code <= "Z") begin
            o_sprite_y = ROW_UPPER_Y;
            // A=0, B=5, C=10...
            o_sprite_x = (char_code - "A") * CHAR_W;
        end
        
        // --------------------------------------------------
        // 3. ตัวเลขและสัญลักษณ์ -> Y = 150 หรือ 158
        // --------------------------------------------------
        else begin
            // เลือกแถว Y ตาม Input
            if (is_small_font) o_sprite_y = ROW_NUM2_Y;
            else               o_sprite_y = ROW_NUM1_Y;
            
            // --- Logic หาตำแหน่ง X (ลำดับ: 1 2 3 4 5 6 7 8 9 0 ? ! / ? ? - + =) ---
            
            // กลุ่มตัวเลข 1-9
            if (char_code >= "1" && char_code <= "9") begin
                o_sprite_x = (char_code - "1") * CHAR_W;
            end
            
            // เลข 0 (อยู่ตัวที่ 10 -> index 9)
            else if (char_code == "0") o_sprite_x = 9 * CHAR_W;
            
            // สัญลักษณ์ต่างๆ (เรียงตามลำดับใน Sprite Sheet)
            else if (char_code == "?") o_sprite_x = 10 * CHAR_W;
            else if (char_code == "!") o_sprite_x = 11 * CHAR_W;
            else if (char_code == "/") o_sprite_x = 12 * CHAR_W;
            
            // Map ปุ่ม '%' ให้เป็นรูป 'เครื่องหมายหาร' (ตัวที่ 14 -> index 13)
            else if (char_code == "%") o_sprite_x = 13 * CHAR_W; 
            
            // Map ปุ่ม '*' ให้เป็นรูป 'เครื่องหมายคูณ' (ตัวที่ 15 -> index 14)
            else if (char_code == "*") o_sprite_x = 14 * CHAR_W; 
            
            else if (char_code == "-") o_sprite_x = 15 * CHAR_W;
            else if (char_code == "+") o_sprite_x = 16 * CHAR_W;
            else if (char_code == "=") o_sprite_x = 17 * CHAR_W;
            
            // อื่นๆ (เช่น Space bar)
            else o_sprite_x = 0; // หรือชี้ไปที่พื้นที่ว่าง
        end
    end

endmodule