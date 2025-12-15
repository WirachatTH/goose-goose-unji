`timescale 1ns / 1ps

module heartDrawer(
    input [9:0] x,
    input [9:0] y,
    input [2:0] hp_count, 
    
    input [9:0] pos_x, 
    input [9:0] pos_y,
    
    output heart_render,
    output [15:0] heart_rom_addr
    );

    // CONFIG
    parameter HEART_W = 19;
    parameter HEART_H = 17;
    parameter SPACING = 2;
    parameter UNIT_W  = HEART_W + SPACING; // 19+2 = 21
    
    parameter SPRITE_W = 256;
    parameter SPRITE_Y_START = 46;
    
    parameter OFF_FULL_X  = 107;
    parameter OFF_HALF_X  = 127;
    parameter OFF_EMPTY_X = 147;

    // HIT TEST
    wire [9:0] total_width = (HEART_W * 3) + (SPACING * 2);
    wire in_box = (x >= pos_x) && (x < pos_x + total_width) && 
                  (y >= pos_y) && (y < pos_y + HEART_H);
                  
    wire [9:0] rel_x = x - pos_x;
    
    // *** แก้ไข: เปลี่ยนการหารเป็น if-else (เร็วกว่ามาก) ***
    reg [1:0] heart_idx;
    reg [9:0] pixel_off_x;
    
    always @(*) begin
        if (rel_x < UNIT_W) begin
            heart_idx = 0;
            pixel_off_x = rel_x;
        end else if (rel_x < (UNIT_W * 2)) begin
            heart_idx = 1;
            pixel_off_x = rel_x - UNIT_W;
        end else begin
            heart_idx = 2;
            pixel_off_x = rel_x - (UNIT_W * 2);
        end
    end
    
    // ถ้าตกในช่องว่าง (Spacing) ไม่ต้องวาด
    wire is_spacing = (pixel_off_x >= HEART_W);

    // LOGIC เลือกรูปภาพ
    reg [9:0] current_sprite_x;
    always @(*) begin
        current_sprite_x = OFF_EMPTY_X;
        case (heart_idx)
            2'd0: begin
                if (hp_count >= 6)      current_sprite_x = OFF_FULL_X;
                else if (hp_count == 5) current_sprite_x = OFF_HALF_X;
                else                    current_sprite_x = OFF_EMPTY_X;
            end
            2'd1: begin
                if (hp_count >= 4)      current_sprite_x = OFF_FULL_X;
                else if (hp_count == 3) current_sprite_x = OFF_HALF_X;
                else                    current_sprite_x = OFF_EMPTY_X;
            end
            2'd2: begin
                if (hp_count >= 2)      current_sprite_x = OFF_FULL_X;
                else if (hp_count == 1) current_sprite_x = OFF_HALF_X;
                else                    current_sprite_x = OFF_EMPTY_X;
            end
        endcase
    end

    assign heart_render = in_box && !is_spacing;
    wire [9:0] pixel_off_y = y - pos_y;
    
    assign heart_rom_addr = (heart_render) ?
        ( ({6'b0, SPRITE_Y_START} + pixel_off_y) * SPRITE_W ) + (current_sprite_x + pixel_off_x)
        : 16'd0;

endmodule