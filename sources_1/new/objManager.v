`timescale 1ns / 1ps

module objManager(
    input Clk_In,           
    input Reset,
    input GameTick,        
    input [2:0] currentState,
    input [2:0] currentWeather,
    input [9:0] x,          
    input [9:0] y,
    
    // Character Info
    input [9:0] char_x,
    input [9:0] char_y,
    input [9:0] char_w,
    input [9:0] char_h,
    input [9:0] gun_count,
    input is_invincible,
    
    //Handshake Input
    input is_firing, 
     
    output obj_render,         
    output [15:0] w_obj_rom_addr,
    output reg [2:0] collisionType,
    output reg [7:0] bonus_score_from_obj,
    
    //Handshake Output
    output reg bullet_fired_ack,
    
    output reg expl_trigger,
    output reg [1:0] expl_type, //0,1 Poo ระเบิด และ 2,3 Goose (มีแอนิเมชั่นต่างกันตามสภาพอากาศ)
    output reg expl_moving, //1 Moving(ยิงปืนใส่วัตถุ), 0 Still(เราเดินชนวัตถุ)
    output reg [9:0] expl_x,
    output reg [9:0] expl_y,
    
    output [3:0] current_speed
    );

    //Config
    parameter sunny = 3'b000;
    parameter rainy = 3'b001;
    parameter snowy = 3'b010;
    
    parameter startState = 3'b000;
    parameter gameState = 3'b001;
    parameter freezeState = 3'b011;
        
    parameter num_Strips = 7;
    
    reg [3:0] obj_Speed;
    reg [12:0] speed_timer;
    parameter MIN_SPEED = 3;
    parameter MAX_SPEED = 5;
    parameter TICKS_PER_SPEED_UP = 4200; //70 seconds per +1 speed
    assign current_speed = obj_Speed;
    
    parameter spacing = 115;
    parameter spawn_offset_y = 40;
    parameter TOTAL_HEIGHT = num_Strips * spacing;
    
    parameter TYPE_EMPTY = 3'b000;
    parameter STILL_POO  = 3'b001;
    parameter WALK_POO   = 3'b010;
    parameter GUN        = 3'b011;
    parameter GOOSE      = 3'b100;
    parameter BULLET     = 3'b101;
    parameter MEDKIT     = 3'b110;
    parameter PILL       = 3'b111;
    
    parameter SPRITE_SHEET_W = 256;
    parameter LANE_WIDTH = 64;   
    parameter LEFT_BORDER = 160;

    //x y offsets in sprite
    parameter GOOSE_W = 26; parameter GOOSE_H = 25;
    parameter GOOSE_OFFSET_X = 205; parameter GOOSE_OFFSET_Y = 46;
    parameter GOOSE_OFFSET_X_FREEZE = 205; parameter GOOSE_OFFSET_Y_FREEZE = 97;

    parameter STILL_POO_W = 19; parameter STILL_POO_H = 17;
    parameter STILL_POO_OFFSET_X = 120; parameter STILL_POO_OFFSET_Y = 0;
    parameter STILL_POO_OFFSET_X_FREEZE = 120; parameter STILL_POO_OFFSET_Y_FREEZE = 21;

    parameter WALK_POO_W = 21; parameter WALK_POO_H = 21;
    parameter WALK_POO_OFFSET_X = 76; parameter WALK_POO_OFFSET_Y = 0;
    parameter WALK_POO_OFFSET_X_RAIN = 98; parameter WALK_POO_OFFSET_Y_RAIN = 0;
    parameter WALK_POO_OFFSET_X_FREEZE = 76; parameter WALK_POO_OFFSET_Y_FREEZE = 21;

    parameter GUN_W = 18; parameter GUN_H = 13;
    parameter GUN_OFFSET_X = 229; parameter GUN_OFFSET_Y = 0;
    
    parameter BULLET_W = 3; parameter BULLET_H = 5;
    parameter BULLET_OFFSET_X = 248; parameter BULLET_OFFSET_Y = 6;

    parameter MAX_BULLETS = 10; 
    parameter BULLET_SPD = 10;
    reg bullet_active [0:MAX_BULLETS-1];
    reg [9:0] bullet_x [0:MAX_BULLETS-1];
    reg [9:0] bullet_y [0:MAX_BULLETS-1];
    
    parameter MEDKIT_W = 19; parameter MEDKIT_H = 16;
    parameter MEDKIT_OFFSET_X = 229; parameter MEDKIT_OFFSET_Y = 13;
    
    parameter PILL_W = 14; parameter PILL_H = 14;
    parameter PILL_OFFSET_X = 229; parameter PILL_OFFSET_Y = 29;

    reg [4:0] obj_pattern [0:num_Strips-1];
    reg signed [11:0] obj_pos_y [0:num_Strips-1];
    reg signed [11:0] obj_offset_x [0:num_Strips-1][0:4];
    reg [2:0] wrap_idx = 3'd0;           
    reg [2:0] obj_type [0:num_Strips-1][0:4]; 
    reg obj_dir [0:num_Strips-1][0:4];
    
    reg [9:0] box_obj_x, box_obj_y;
    reg [8:0] box_w, box_h;
    reg [9:0] char_padding_x, char_padding_y, obj_padding_x;
    reg select_enable;
    
    wire [15:0] randomize_value;
    wire [4:0] selected_new_pattern;
    randomizer u_random (.Reset(Reset), .GameTick(GameTick), .randomize_value(randomize_value));
    patternSelector u_pattern (.GameTick(GameTick), .randomize_value(randomize_value), .select_enable(select_enable), .new_pattern(selected_new_pattern));

    integer i, k, b;
    reg is_l2_walker, is_l4_walker;
    reg [3:0] rand_l1, rand_l2, rand_l3, rand_l4, rand_l5;
    reg [9:0] g_x;
    reg [2:0] g_lane;

    //Dynamic Speed เปลี่ยนแปลงได้ตามเงื่อนไข
    reg [2:0] goose_spd;
    reg [2:0] walk_poo_spd;
    reg [9:0] curr_goose_x, curr_goose_y;
    reg [9:0] curr_walk_x, curr_walk_y;
    reg [9:0] curr_still_x, curr_still_y;

    //Textures เปลี่ยนแปลงได้ตามเงื่อนไข
    always @(*) begin
        case (currentWeather)
            rainy : begin
                goose_spd = 3'd6; walk_poo_spd = 3'd5;
                curr_goose_x = GOOSE_OFFSET_X;      curr_goose_y = GOOSE_OFFSET_Y;
                curr_walk_x  = WALK_POO_OFFSET_X_RAIN; curr_walk_y  = WALK_POO_OFFSET_Y_RAIN;
                curr_still_x = STILL_POO_OFFSET_X;  curr_still_y = STILL_POO_OFFSET_Y;
            end 
            snowy : begin
                goose_spd = 3'd3; walk_poo_spd = 3'd2;
                curr_goose_x = GOOSE_OFFSET_X_FREEZE;      curr_goose_y = GOOSE_OFFSET_Y_FREEZE;
                curr_walk_x  = WALK_POO_OFFSET_X_FREEZE;   curr_walk_y  = WALK_POO_OFFSET_Y_FREEZE;
                curr_still_x = STILL_POO_OFFSET_X_FREEZE;  curr_still_y = STILL_POO_OFFSET_Y_FREEZE;
            end 
            default : begin
                goose_spd = 3'd4; walk_poo_spd = 3'd3;
                curr_goose_x = GOOSE_OFFSET_X;      curr_goose_y = GOOSE_OFFSET_Y;
                curr_walk_x  = WALK_POO_OFFSET_X;   curr_walk_y  = WALK_POO_OFFSET_Y;
                curr_still_x = STILL_POO_OFFSET_X;  curr_still_y = STILL_POO_OFFSET_Y;
            end
        endcase
    end

    //ฟังก์ชันเพื่อคำนวณว่า x ในตอนี้อยู่เลนไหน
    function [2:0] get_lane_from_x;
    input [11:0] x_pos; 
        reg signed [11:0] lane_rel;
        begin
            lane_rel = x_pos - LEFT_BORDER;
            if (lane_rel < 0) get_lane_from_x = 3'd7; 
            else if (lane_rel >= (LANE_WIDTH * 5)) get_lane_from_x = 3'd7;
            else get_lane_from_x = lane_rel[11:6]; 
        end
    endfunction
    
    //ปรับ Hit Box ให้ตัวละคร
    always @(*) begin
        if (gun_count != 0) char_padding_x = 3; else char_padding_x = 7;
        char_padding_y = 25;
    end

    /*----------SPAWNING, ABILITIES, AND COLLISION----------*/
    always @(posedge GameTick or negedge Reset) begin
        if (!Reset) begin
            wrap_idx <= 0;
            bullet_fired_ack <= 0;
            collisionType <= 0; bonus_score_from_obj <= 0;
            obj_Speed <= MIN_SPEED;
            speed_timer <= 0;
            expl_trigger <= 0;
            for (i=0; i<num_Strips; i=i+1) begin
                obj_pos_y[i] <= $signed(-spawn_offset_y) - $signed(i * spacing);
                for(k=0; k<5; k=k+1) begin obj_type[i][k] <= TYPE_EMPTY; obj_offset_x[i][k] <= 0; end
            end
            for (b=0; b<MAX_BULLETS; b=b+1) bullet_active[b] <= 0;
        end else if (currentState == startState) begin //ให้ทุกแถบกลับไปว่างเปล่าและอยู่เหนือจอ
            wrap_idx <= 0;
            bullet_fired_ack <= 0;
            obj_Speed <= MIN_SPEED;
            speed_timer <= 0;
            for (i=0; i<num_Strips; i=i+1) begin
                obj_pos_y[i] <= $signed(-spawn_offset_y) - $signed(i * spacing);
                for(k=0; k<5; k=k+1) begin obj_type[i][k] <= TYPE_EMPTY; obj_offset_x[i][k] <= 0; end
            end
            for (b=0; b<MAX_BULLETS; b=b+1) bullet_active[b] <= 0;
        end else begin
            expl_trigger <= 0; 
            
            if (currentState == gameState) begin
                collisionType <= 0; bonus_score_from_obj <= 0;
                select_enable <= 0; bullet_fired_ack <= 0;
                
                if (obj_Speed < MAX_SPEED) begin //เพิ่ม Speed เกมทีละ 1 ทุก 70 วินาที
                    if (speed_timer < TICKS_PER_SPEED_UP) begin
                        speed_timer <= speed_timer + 1;
                    end else begin
                        speed_timer <= 0;
                        obj_Speed <= obj_Speed + 1;
                    end
                end
                //ยิงและสั่ง Render กระสุน
                if (is_firing) begin
                    begin : spawn_blk
                        for (b=0; b<MAX_BULLETS; b=b+1) begin
                            if (!bullet_active[b]) begin
                                bullet_active[b] <= 1;
                                bullet_x[b] <= (char_x + 12) - (BULLET_W >> 1);
                                bullet_y[b] <= char_y + 8;
                                bullet_fired_ack <= 1;
                                disable spawn_blk;
                            end
                        end
                    end
                end
                //การเคลื่อนที่ของกระสุนสำหรับกระสุนที่ถูกยิงไปแล้ว
                for (b=0; b<MAX_BULLETS; b=b+1) begin
                    if (bullet_active[b]) begin
                        if ($signed(bullet_y[b]) < -10) bullet_active[b] <= 0;
                        else bullet_y[b] <= bullet_y[b] - BULLET_SPD;
                    end
                end

                //Strip & Object Logic
                for (i=0; i<num_Strips; i=i+1) begin
                    obj_pos_y[i] <= obj_pos_y[i] + obj_Speed;
                    
                    for (k=0; k<5; k=k+1) begin
                        //GOOSE MOVEMENT AND ABILITY
                        if (obj_type[i][k] == GOOSE) begin
                            if (obj_pos_y[i] >= 30) obj_offset_x[i][k] <= obj_offset_x[i][k] - goose_spd; //Horizontal movement
                            
                            //โอกาสสุ่มที่จะ Spawn STILL_POO ขึ้นมากลางทาง
                            g_x = (LEFT_BORDER + (k * 64) + 32) + obj_offset_x[i][k];
                            g_lane = get_lane_from_x({2'b0, g_x});
                            if (g_lane < 5 && g_lane != k && obj_type[i][g_lane] == TYPE_EMPTY) begin
                                if (randomize_value[2:0] == 3'd0) begin  //โอกาส 1 ใน 8
                                    obj_type[i][g_lane] <= STILL_POO;
                                    obj_offset_x[i][g_lane] <= 0;
                                end
                            end
                        end 
                        //WALK_POO MOVEMENT
                        else if (obj_type[i][k] == WALK_POO) begin
                            if ((k==1 || k==3)) begin
                                 if (!obj_dir[i][k]) begin
                                    if (obj_offset_x[i][k] < LANE_WIDTH) obj_offset_x[i][k]<=obj_offset_x[i][k] + walk_poo_spd;
                                    else obj_dir[i][k]<=1;
                                 end else begin
                                    if (obj_offset_x[i][k] > (k==1?0:-64)) obj_offset_x[i][k]<=obj_offset_x[i][k] - walk_poo_spd;
                                    else obj_dir[i][k]<=0;
                                 end
                            end
                        end

                        //COLLISION LOGIC
                        if (obj_type[i][k] != TYPE_EMPTY) begin
                            case(obj_type[i][k]) //กำหนด Bounding Box ให้วัตถุชิ้นนั้นๆที่เจอได้อย่างถูกต้อง
                                GOOSE: begin box_w=GOOSE_W; box_h=GOOSE_H; obj_padding_x=3; end
                                WALK_POO: begin box_w=WALK_POO_W; box_h=WALK_POO_H; obj_padding_x=3; end
                                STILL_POO: begin box_w=STILL_POO_W; box_h=STILL_POO_H; obj_padding_x=3; end
                                GUN: begin box_w=GUN_W; box_h=GUN_H; obj_padding_x=0; end
                                MEDKIT: begin box_w=MEDKIT_W; box_h=MEDKIT_H; obj_padding_x=1; end
                                PILL: begin box_w=PILL_W; box_h=PILL_H; obj_padding_x = 0; end
                                default: begin box_w=GUN_W; box_h=GUN_H; obj_padding_x=0; end
                            endcase
                            //คำนวณ Position ปัจจุบันของวัตถุชิ้นนั้นๆ
                            box_obj_x = (LEFT_BORDER + (k*64) + 32 - (box_w/2)) + obj_offset_x[i][k];
                            box_obj_y = obj_pos_y[i];

                            //ตรวจสอบการชนกันกับตัวละคร
                            if ((char_x+char_padding_x < box_obj_x-obj_padding_x+box_w) && (char_x-char_padding_x+char_w > box_obj_x+obj_padding_x) &&
                                (char_y+char_padding_y < box_obj_y+box_h) && (char_y - 3 +char_h > box_obj_y+3)) begin
                                if (obj_type[i][k] == GUN) begin
                                    collisionType <= 3'b001; obj_type[i][k] <= TYPE_EMPTY;
                                end else if (obj_type[i][k] == MEDKIT) begin
                                    collisionType <= 3'b100; obj_type[i][k] <= TYPE_EMPTY;
                                end else if (obj_type[i][k] == PILL) begin
                                    collisionType <= 3'b101; obj_type[i][k] <= TYPE_EMPTY;
                                end else if (!is_invincible) begin
                                    collisionType <= (obj_type[i][k]==GOOSE) ? 3'b011 : 3'b010;
                                    expl_trigger <= 1; expl_x <= box_obj_x; expl_y <= box_obj_y; expl_moving <= 0;
                                    if (obj_type[i][k] == GOOSE) expl_type <= (currentWeather == snowy) ? 2'd3 : 2'd2;
                                    else expl_type <= (currentWeather == snowy) ? 2'd1 : 2'd0;
                                    obj_type[i][k] <= TYPE_EMPTY;
                                end
                            end
                            
                            //ตรวจสอบการชนกันกับกระสุนปืน
                            if (obj_type[i][k] != GUN) begin
                                for(b=0; b<MAX_BULLETS; b=b+1) begin
                                    if (bullet_active[b] && bullet_x[b] < box_obj_x-obj_padding_x+box_w && bullet_x[b]+3 > box_obj_x+obj_padding_x &&
                                        bullet_y[b] < box_obj_y+box_h && bullet_y[b]+5 > box_obj_y+3) begin
                                        expl_trigger <= 1; expl_x <= box_obj_x; expl_y <= box_obj_y; expl_moving <= 1;
                                        if (obj_type[i][k] == GOOSE) expl_type <= (currentWeather == snowy) ? 2'd3 : 2'd2;
                                        else expl_type <= (currentWeather == snowy) ? 2'd1 : 2'd0;
                                        obj_type[i][k] <= TYPE_EMPTY;
                                        bullet_active[b] <= 0;
                                        bonus_score_from_obj <= (obj_type[i][k]==GOOSE) ? 5 : (obj_type[i][k]==WALK_POO ? 2 : 1);
                                    end
                                end
                            end
                        end
                    end 
                end

                /* ------ Spawning Logic ------ */
                if (obj_pos_y[wrap_idx] > 480) begin
                    select_enable <= 1;
                    obj_pos_y[wrap_idx] <= obj_pos_y[wrap_idx] - $signed(TOTAL_HEIGHT);
                    obj_pattern[wrap_idx] <= selected_new_pattern;
                    for (k=0; k<5; k=k+1) obj_offset_x[wrap_idx][k] <= 0;

                    //ดึงค่าขนาดต่างๆจากตำแหน่งต่างๆ ของ randomize_value เพื่อเพิ่ม/ลดความน่าจะเป็นให้แตกต่างกัน
                    rand_l1 = randomize_value[3:0]; rand_l2 = randomize_value[6:4];
                    rand_l3 = randomize_value[9:7]; rand_l4 = randomize_value[12:10]; rand_l5 = randomize_value[15:13];
                    if (selected_new_pattern[1] && rand_l2 < 2) is_l2_walker = 1; else is_l2_walker = 0;
                    if (selected_new_pattern[3] && rand_l4 < 2) is_l4_walker = 1; else is_l4_walker = 0;
                    
                    if (selected_new_pattern == 5'b10000) begin //GOOSE เดินจากขวาไปซ้ายเท่านั้น จึงเกิดเลนขวาสุด
                        obj_type[wrap_idx][4] <= GOOSE;
                        obj_type[wrap_idx][3] <= TYPE_EMPTY; obj_type[wrap_idx][2] <= TYPE_EMPTY;
                        obj_type[wrap_idx][1] <= TYPE_EMPTY; obj_type[wrap_idx][0] <= TYPE_EMPTY;
                    end else begin
                        if (selected_new_pattern[0]) begin
                            if (rand_l1 == 0) begin
                                obj_type[wrap_idx][0] <= (rand_l2[0]) ? GUN : ( (rand_l2[1]) ? MEDKIT : PILL );
                            end else begin
                                obj_type[wrap_idx][0] <= STILL_POO;
                            end
                        end else begin
                            obj_type[wrap_idx][0] <= TYPE_EMPTY;
                        end
                        if (selected_new_pattern[1]) obj_type[wrap_idx][1] <= (is_l2_walker) ? WALK_POO : STILL_POO; else obj_type[wrap_idx][1] <= TYPE_EMPTY;
                        if (selected_new_pattern[2]) obj_type[wrap_idx][2] <= (is_l2_walker || is_l4_walker) ? TYPE_EMPTY : STILL_POO; else obj_type[wrap_idx][2] <= TYPE_EMPTY;
                        if (selected_new_pattern[3]) obj_type[wrap_idx][3] <= (is_l4_walker) ? WALK_POO : STILL_POO; else obj_type[wrap_idx][3] <= TYPE_EMPTY;
                        if (selected_new_pattern[4]) begin
                            if (is_l4_walker) begin
                                obj_type[wrap_idx][4] <= TYPE_EMPTY;
                            end else begin
                                //จุดที่เกิดไอเทม จะแบ่งเป็น 50% GUN, 25% MEDKIT, 25% PILL
                                if (rand_l5 == 0) begin
                                    obj_type[wrap_idx][4] <= (rand_l4[0]) ? GUN : ( (rand_l4[1]) ? MEDKIT : PILL );
                                end else begin
                                    obj_type[wrap_idx][4] <= STILL_POO;
                                end
                            end
                        end else begin
                            obj_type[wrap_idx][4] <= TYPE_EMPTY;
                        end
                    end
                    wrap_idx <= (wrap_idx + 1) % num_Strips;
                end
            end 
        end
    end

    /*----------RENDERING PIPELINE----------*/
    
    /*--- STAGE 1: พิจารณาแต่ละ Strip ---*/
    reg s1_valid;
    reg [9:0] s1_x;
    reg signed [11:0] s1_dist_y;
    reg [2:0] row_cache_type [0:4];
    reg signed [11:0] row_cache_offset [0:4];
    integer r;
    reg signed [11:0] dist_check;
    reg found_strip;
    reg [2:0] found_idx;

    always @(posedge Clk_In) begin
        s1_x <= x;
        found_strip = 0; found_idx = 0; s1_dist_y <= 0;
        
        for (r=0; r<num_Strips; r=r+1) begin
            dist_check = $signed({2'b00, y}) - obj_pos_y[r];
            //เช็คว่า Strip ใดๆ มันอยู่ในพื้นที่ที่ควร Render หรือไม่ จะได้ไม่ต้องไปเสียเวลาดูแถบที่มันตกขอบจอ
            if (dist_check >= 0 && dist_check < 50) begin
                found_strip = 1; found_idx = r[2:0]; s1_dist_y <= dist_check;
            end
        end
        s1_valid <= found_strip;
        if (found_strip) begin
            for(k=0;k<5;k=k+1) begin 
                row_cache_type[k] <= obj_type[found_idx][k];
                row_cache_offset[k] <= obj_offset_x[found_idx][k]; 
            end
        end
    end

    /*--- STAGE 2: ตรวจสอบวัตถุใน 5 เลนของทั้งแถบ ---*/
    reg s2_hit;
    reg [15:0] s2_addr;
    reg [9:0] s2_x, s2_y;
    
    reg [2:0] t_type;
    reg [9:0] t_w, t_h, t_off_x, t_off_y;
    reg [9:0] t_center;
    reg signed [11:0] t_final_x, t_diff_x;
    
    reg hit_any;
    reg [15:0] addr_any;
    integer j;

    always @(posedge Clk_In) begin
        s2_x <= s1_x; s2_y <= y; 
        s2_hit <= 0; s2_addr <= 0;
        
        hit_any = 0; addr_any = 0;
        
        if (s1_valid) begin
            //Check all 5 logic slots
            for(j=0; j<5; j=j+1) begin
                t_type = row_cache_type[j];
                if (t_type != TYPE_EMPTY) begin
                    //ถ้ามีวัตถุ ให้ไปดึง texture มาตาม type
                     case(t_type)
                        STILL_POO: begin t_w=STILL_POO_W; t_h=STILL_POO_H; t_off_x=curr_still_x; t_off_y=curr_still_y; end
                        WALK_POO:  begin t_w=WALK_POO_W; t_h=WALK_POO_H; t_off_x=curr_walk_x;  t_off_y=curr_walk_y; end
                        GUN:       begin t_w=GUN_W; t_h=GUN_H; t_off_x=GUN_OFFSET_X; t_off_y=GUN_OFFSET_Y; end
                        GOOSE:     begin t_w=GOOSE_W; t_h=GOOSE_H; t_off_x=curr_goose_x; t_off_y=curr_goose_y; end
                        MEDKIT:    begin t_w=MEDKIT_W; t_h=MEDKIT_H; t_off_x=MEDKIT_OFFSET_X; t_off_y=MEDKIT_OFFSET_Y; end
                        PILL:      begin t_w=PILL_W; t_h=PILL_H; t_off_x=PILL_OFFSET_X; t_off_y=PILL_OFFSET_Y; end
                        default:   begin t_w=0;  t_h=0;  t_off_x=0; t_off_y=0; end
                    endcase
                    
                    //วางวัตถุไว้ตรงกลางเลนที่มันอยู่
                    //Base Centers: 192, 256, 320, 384, 448
                    case(j)
                        0: t_center = 192; 1: t_center = 256; 2: t_center = 320;
                        3: t_center = 384; 4: t_center = 448; default: t_center = 0;
                    endcase
                    
                    t_final_x = $signed({2'b00, t_center - (t_w>>1)}) + row_cache_offset[j];
                    t_diff_x = $signed({2'b00, s1_x}) - t_final_x;

                    //ถ้า x y ของ vga โดนวัตถุ ก็ส่ง address กลับไป
                    if ($unsigned(t_diff_x) < t_w && $unsigned(s1_dist_y) < t_h) begin
                        hit_any = 1;
                        addr_any = { (t_off_y[7:0] + s1_dist_y[7:0]), (t_off_x[7:0] + t_diff_x[7:0]) };
                    end
                end
            end
            
            if (hit_any) begin
                s2_hit <= 1;
                s2_addr <= addr_any;
            end
        end
    end

    /*--- STAGE 3 แล้วค่อยเพิ่มการ Render กระสุนในขั้นสุดท้าย ---*/
    reg [9:0] r3_x, r3_y;
    reg r3_obj_hit;
    reg [15:0] r3_obj_addr;
    reg r3_bullet_hit;
    reg [9:0] r3_b_draw_x, r3_b_draw_y;
    integer bb;
    
    always @(posedge Clk_In) begin
        r3_x <= s2_x; r3_y <= s2_y;
        r3_obj_hit <= s2_hit;
        r3_obj_addr <= s2_addr;
        r3_bullet_hit <= 0;
        
        for (bb=0; bb<MAX_BULLETS; bb=bb+1) begin
            if (bullet_active[bb]) begin
                if (s2_x >= bullet_x[bb] && s2_x < bullet_x[bb]+3 &&
                    s2_y >= bullet_y[bb] && s2_y < bullet_y[bb]+5) begin
                    r3_bullet_hit <= 1;
                    r3_b_draw_x <= bullet_x[bb];
                    r3_b_draw_y <= bullet_y[bb];
                end
            end
        end
    end

    wire [7:0] b_y_addr = 8'd6 + (r3_y[7:0] - r3_b_draw_y[7:0]);
    wire [7:0] b_x_addr = 8'd248 + (r3_x[7:0] - r3_b_draw_x[7:0]);
    assign obj_render = r3_obj_hit | r3_bullet_hit;
    assign w_obj_rom_addr = r3_obj_hit ? r3_obj_addr : (r3_bullet_hit ? { b_y_addr, b_x_addr } : 0);
endmodule