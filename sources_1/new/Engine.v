`timescale 1ns / 1ps

module Engine(
    input Clk_In,
    input Reset,
    input GameTick,
    input Left,
    input Right,
    input Shoot,
    input SwitchItem,
    input StartStop,
    input [9:0] x,
    input [9:0] y,
    
    output [3:0] RED,
    output [3:0] GREEN,
    output [3:0] BLUE
    );

    // =========================================================
    // INPUT PULSE LOGIC
    // =========================================================
    reg StartStop_Prev, Shoot_Prev, GameTick_Prev;
    wire Start_Pulse = StartStop && !StartStop_Prev;
    wire Shoot_Pulse = Shoot && !Shoot_Prev;
    wire GameTick_Pulse = GameTick && !GameTick_Prev;

    always @(posedge Clk_In) begin
        StartStop_Prev <= StartStop;
        Shoot_Prev <= Shoot;
        GameTick_Prev <= GameTick;
    end
    
    reg [2:0] currentState;
    parameter startState = 3'b000;
    parameter gameState = 3'b001;
    parameter pauseState = 3'b010;
    parameter freezeState = 3'b011;
    parameter endState = 3'b100;
    
    wire [2:0] currentWeather;
    parameter sunny = 3'b000;
    parameter rainy = 3'b001;
    parameter snowy = 3'b010;
    
    wire [3:0] w_global_speed;

    weatherController u_weather(
        .Reset(Reset),
        .GameTick(GameTick),
        .currentState(currentState),
        .currentWeather(currentWeather)
    );

    reg [2:0] HP_Count;
    reg [1:0] score_tick_counter;
    parameter freeze_MAX = 120;
    parameter invincible_MAX = 240;
    reg [6:0] freeze_timer;
    reg [7:0] invincible_timer;
    wire [7:0] bonus_score_from_obj;
    parameter sprite_w = 256; 
    reg show_hud;
    reg gun_count_active;
    
    reg is_shooting_req; 
    wire bullet_fired_ack;

    // =========================================================
    // BCD SCORING SYSTEM
    // =========================================================
    reg [3:0] score_d0, score_d1, score_d2, score_d3, score_d4, score_d5, score_d6;
    reg [3:0] gun_d0, gun_d1, gun_d2;
    
    // Calculate total for logic checks
    wire [9:0] gun_count = (gun_d2 * 100) + (gun_d1 * 10) + gun_d0;

    task inc_gun_bcd;
        begin
            if (!(gun_d2 == 9 && gun_d1 == 9 && gun_d0 == 9)) begin
                if (gun_d0 < 9) gun_d0 <= gun_d0 + 1;
                else begin
                    gun_d0 <= 0;
                    if (gun_d1 < 9) gun_d1 <= gun_d1 + 1;
                    else begin
                        gun_d1 <= 0;
                        if (gun_d2 < 9) gun_d2 <= gun_d2 + 1;
                    end
                end
            end
        end
    endtask
    
    task dec_gun_bcd;
        begin
            if (!(gun_d2 == 0 && gun_d1 == 0 && gun_d0 == 0)) begin
                if (gun_d0 > 0) gun_d0 <= gun_d0 - 1;
                else begin
                    gun_d0 <= 9;
                    if (gun_d1 > 0) gun_d1 <= gun_d1 - 1;
                    else begin
                        gun_d1 <= 9;
                        if (gun_d2 > 0) gun_d2 <= gun_d2 - 1;
                    end
                end
            end
        end
    endtask
    
    task inc_score_bcd;
        begin
            if (!(score_d0 == 9 && score_d1 == 9 && score_d2 == 9 && score_d3 == 9 && score_d4 == 9 && score_d5 == 9 && score_d6 == 9)) begin
                if (score_d0 < 9) score_d0 <= score_d0 + 1;
                else begin
                    score_d0 <= 0;
                    if (score_d1 < 9) score_d1 <= score_d1 + 1;
                    else begin
                        score_d1 <= 0;
                        if (score_d2 < 9) score_d2 <= score_d2 + 1;
                        else begin
                            score_d2 <= 0;
                            if (score_d3 < 9) score_d3 <= score_d3 + 1;
                            else begin
                                score_d3 <= 0;
                                if (score_d4 < 9) score_d4 <= score_d4 + 1;
                                else begin
                                    score_d4 <= 0;
                                    if (score_d5 < 9) score_d5 <= score_d5 + 1;
                                    else begin
                                        score_d5 <= 0;
                                        if (score_d6 < 9) score_d6 <= score_d6 + 1;
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    endtask

    // =========================================================
    // CHARACTER LOGIC
    // =========================================================
    parameter char_w_type1 = 25;
    parameter char_h_type1 = 40;
    parameter char_w_type2 = 17; parameter char_h_type2 = 40;
    parameter char_offset_x_0 = 0;  parameter char_offset_y_0 = 0;
    parameter char_offset_x_1 = 26; parameter char_offset_y_1 = 0;
    parameter char_offset_x_2 = 51; parameter char_offset_y_2 = 0;
    parameter char_offset_x_3 = 0;
    parameter char_offset_y_3 = 41;
    parameter char_offset_x_4 = 18; parameter char_offset_y_4 = 41;

    wire [2:0] char_frame;
    reg [9:0] char_w, char_h, char_off_x, char_off_y;
    
    always @(*) begin
        case (char_frame)
            3'd0: begin char_w=char_w_type1; char_h=char_h_type1; char_off_x=0; char_off_y=0; end
            3'd1: begin char_w=char_w_type1; char_h=char_h_type1; char_off_x=26; char_off_y=0; end
            3'd2: begin char_w=char_w_type1; char_h=char_h_type1; char_off_x=51; char_off_y=0; end
            3'd3: begin char_w=char_w_type2; char_h=char_h_type2; char_off_x=0; char_off_y=41; end
            3'd4: begin char_w=char_w_type2; char_h=char_h_type2; char_off_x=18; char_off_y=41; end
            default: begin char_w=char_w_type1; char_h=char_h_type1; char_off_x=0; char_off_y=0; end
        endcase
    end

    wire [9:0] char_x, char_y;
    wire [7:0] char_calc_y = char_off_y[7:0] + (y[7:0] - char_y[7:0]);
    wire [7:0] char_calc_x = char_off_x[7:0] + (x[7:0] - char_x[7:0]);
    wire [15:0] w_char_final_addr = { char_calc_y, char_calc_x };
    wire charArea = (x >= char_x) && (x < char_x + char_w) && (y >= char_y) && (y < char_y + char_h);
    wire charActive; 
    reg is_invincible;

    character u_char (
        .Reset(Reset), .GameTick(GameTick), 
        .Left(Left), .Right(Right), .currentState(currentState), .gun_count(gun_count), .is_invincible(is_invincible),
        .char_frame(char_frame), .x_out(char_x), .y_out(char_y), .is_visible(charActive)
    );

    // =========================================================
    // CLOUDS LOGIC
    // =========================================================
    parameter cloud1_w = 550;
    parameter cloud1_h = 210;
    parameter cloud1_sprite_x = 0; parameter cloud1_sprite_y = 90;
    parameter cloud1_min_y = -210; parameter cloud1_max_y = -50;
    reg signed [11:0] cloud1_pos_y;
    
    wire signed [11:0] cloud_diff_y = $signed({1'b0, y}) - cloud1_pos_y;
    wire signed [11:0] cloud_diff_x = $signed({1'b0, x}) - 45;
    wire cloud_hit = (cloud_diff_x >= 0) && (cloud_diff_x < cloud1_w) && (cloud_diff_y >= 0) && (cloud_diff_y < cloud1_h);
    wire [9:0] scaled_cloud_y = (cloud_diff_y * 205) >> 10;
    wire [9:0] scaled_cloud_x = (cloud_diff_x * 205) >> 10;
    
    wire [7:0] cloud_addr_y = cloud1_sprite_y[7:0] + scaled_cloud_y[7:0];
    wire [7:0] cloud_addr_x = cloud1_sprite_x[7:0] + scaled_cloud_x[7:0];
    wire [15:0] w_cloud_addr = { cloud_addr_y, cloud_addr_x };

    // =========================================================
    // OBJECT LOGIC
    // =========================================================
    wire obj_render_flag;
    wire [15:0] w_obj_addr;
    wire [2:0] collisionType;
    wire fx_trig;
    wire [1:0] fx_type;
    wire fx_mov;
    wire [9:0] fx_x, fx_y;
    
    wire fx_render;
    wire [15:0] fx_addr;
    ExplosionFxManager u_fx (
        .Clk_In(Clk_In), .Reset(Reset), .GameTick(GameTick),
        .currentState(currentState),
        .world_speed(w_global_speed),
        .trigger_req(fx_trig), 
        .anim_type(fx_type), 
        .is_moving_down(fx_mov),
        .start_x(fx_x), .start_y(fx_y),
        .vga_x(x), .vga_y(y),
        .render_enable(fx_render), .rom_addr(fx_addr)
    );

    objManager u_obj (
        .Clk_In(Clk_In), .Reset(Reset), .GameTick(GameTick),
        .currentState(currentState), .x(x), .y(y), .char_x(char_x), .char_y(char_y), .char_w(char_w), .char_h(char_h),
        .gun_count(gun_count), .is_invincible(is_invincible), 
        .is_firing(is_shooting_req),.bullet_fired_ack(bullet_fired_ack),
        .currentWeather(currentWeather),
        .obj_render(obj_render_flag), .w_obj_rom_addr(w_obj_addr), .collisionType(collisionType), .bonus_score_from_obj(bonus_score_from_obj),
        .expl_trigger(fx_trig), 
        .expl_type(fx_type), 
        .expl_moving(fx_mov),
        .expl_x(fx_x), .expl_y(fx_y),
        .current_speed(w_global_speed)
    );

    // =========================================================
    // UI LOGIC (COMBINATIONAL CALCS)
    // =========================================================
    // Note: These area checks are now registered in the Pipeline block below
    // to match the timing of the Text Logic.
    
    wire barArea = (x >= 500) && (x < 524) && (y >= 424) && (y < 449);
    wire [7:0] bar_calc_y = 8'd42 + (y[7:0] - 8'd168);
    wire [7:0] bar_calc_x = 8'd83 + (x[7:0] - 8'd244);
    wire [15:0] w_bar_final_addr = { bar_calc_y, bar_calc_x };

    wire gunArea = (x >= 503) && (x < 521) && (y >= 430) && (y < 443);
    wire [7:0] gun_calc_y = 8'd0 + (y[7:0] - 8'd174);
    wire [7:0] gun_calc_x = 8'd229 + (x[7:0] - 8'd247);
    wire [15:0] w_gun_final_addr = { gun_calc_y, gun_calc_x };
    wire gunActive = 1; 
    
    wire signArea = (x >= 207) && (x < 432) && (y >= 71) && (y < 140);
    reg [7:0] sign_base_y;
    reg signActive;
    reg [7:0] instruction_base_x; 
    
    always @(*) begin
        case(currentState)
            startState: begin signActive = 1; sign_base_y = 185; instruction_base_x = 0; end
            pauseState: begin signActive = 1; sign_base_y = 208; instruction_base_x = 84; end
            endState:   begin signActive = 1; sign_base_y = 231; instruction_base_x = 126; end
            gameState:  begin signActive = 0; sign_base_y = 0; instruction_base_x = 42; end
            default:    begin signActive = 0; sign_base_y = 0; instruction_base_x = 42; end
        endcase
    end

    wire [9:0] sign_dy = y - 71;
    wire [9:0] sign_dx = x - 207;
    wire [9:0] sign_sprite_y = (sign_dy * 342) >> 10;
    wire [9:0] sign_sprite_x = (sign_dx * 342) >> 10;
    wire [15:0] w_sign_addr = { (sign_base_y + sign_sprite_y[7:0]), sign_sprite_x[7:0] };

    wire instructionArea = (x >= 18) && (x < 141) && (y >= 392) && (y < 449);
    parameter instruction_offset_y = 166;
    wire instructionActive = 1;
    wire [9:0] instruction_dy = y - 392;
    wire [9:0] instruction_dx = x - 18;
    wire [9:0] instruction_sprite_y = (instruction_dy * 342) >> 10;
    wire [9:0] instruction_sprite_x = (instruction_dx * 342) >> 10;
    wire [7:0] instruction_calc_x = instruction_base_x + instruction_sprite_x;
    wire [7:0] instruction_calc_y = instruction_offset_y + instruction_sprite_y;
    wire [15:0] w_instruction_addr = { instruction_calc_y, instruction_calc_x };

    // =========================================================
    // HEART LOGIC
    // =========================================================
    wire heart_active;
    wire [15:0] heart_addr;
    heartDrawer u_heart (.x(x), .y(y), .hp_count(HP_Count),
        .pos_x(10'd500), .pos_y(10'd404),
        .heart_render(heart_active), .heart_rom_addr(heart_addr));

    // =========================================================
    // TEXT MANAGER & PIPELINE STAGE 1 (REGISTRATION)
    // =========================================================
    // In this optimized version, we register ALL UI hits here to align 
    // the pipeline timing. Previously, Text was registered but Sign/Bar were not.
    
    reg [7:0] s1_char_code;
    reg s1_small_font;             
    reg [9:0] s1_txt_rx, s1_txt_ry;
    reg s1_txt_hit;
    
    wire [9:0] map_sprite_x, map_sprite_y;
    FontMapper u_font_map (.char_code(s1_char_code), .is_small_font(s1_small_font), .o_sprite_x(map_sprite_x), .o_sprite_y(map_sprite_y));
    
    // NEW REGISTERS FOR PIPELINE ALIGNMENT
    reg r_signHit, r_barHit, r_gunHit, r_instructionHit, r_heartHit;
    reg [15:0] r_sign_addr, r_bar_addr, r_gun_addr, r_instruction_addr, r_heart_addr;

    always @(posedge Clk_In) begin
        // --- TEXT LOGIC (Existing) ---
        s1_txt_hit <= 0; s1_char_code <= 0; s1_small_font <= 0;
        s1_txt_rx <= 0; s1_txt_ry <= 0;
        
        if (show_hud) begin
            // 5.1 LABEL "SCORE"
            if (y >= 374 && y < 381) begin
                if (x >= 500 && x < 505) begin s1_txt_hit<=1; s1_char_code<="S"; s1_txt_rx<=x-500; s1_txt_ry<=y-374; end
                else if (x >= 506 && x < 511) begin s1_txt_hit<=1; s1_char_code<="C"; s1_txt_rx<=x-506; s1_txt_ry<=y-374; end
                else if (x >= 512 && x < 517) begin s1_txt_hit<=1; s1_char_code<="O"; s1_txt_rx<=x-512; s1_txt_ry<=y-374; end
                else if (x >= 518 && x < 523) begin s1_txt_hit<=1; s1_char_code<="R"; s1_txt_rx<=x-518; s1_txt_ry<=y-374; end
                else if (x >= 524 && x < 529) begin s1_txt_hit<=1; s1_char_code<="E"; s1_txt_rx<=x-524; s1_txt_ry<=y-374; end
            end
            // 5.2 SCORE DIGITS (BCD)
            else if (y >= 385 && y < 392) begin
                if (x >= 500 && x < 505) begin s1_txt_hit<=1; s1_char_code<="0"+score_d6; s1_txt_rx<=x-500; s1_txt_ry<=y-385; end
                else if (x >= 506 && x < 511) begin s1_txt_hit<=1; s1_char_code<="0"+score_d5; s1_txt_rx<=x-506; s1_txt_ry<=y-385; end
                else if (x >= 512 && x < 517) begin s1_txt_hit<=1; s1_char_code<="0"+score_d4; s1_txt_rx<=x-512; s1_txt_ry<=y-385; end
                else if (x >= 518 && x < 523) begin s1_txt_hit<=1; s1_char_code<="0"+score_d3; s1_txt_rx<=x-518; s1_txt_ry<=y-385; end
                else if (x >= 524 && x < 529) begin s1_txt_hit<=1; s1_char_code<="0"+score_d2; s1_txt_rx<=x-524; s1_txt_ry<=y-385; end
                else if (x >= 530 && x < 535) begin s1_txt_hit<=1; s1_char_code<="0"+score_d1; s1_txt_rx<=x-530; s1_txt_ry<=y-385; end
                else if (x >= 536 && x < 541) begin s1_txt_hit<=1; s1_char_code<="0"+score_d0; s1_txt_rx<=x-536; s1_txt_ry<=y-385; end
            end
            // 5.3 GUN COUNT (BCD)
            else if (gun_count_active && y >= 451 && y < 458) begin
                if (x >= 503 && x < 508) begin
                    if (gun_d2 > 0) begin s1_txt_hit<=1; s1_char_code<="0"+gun_d2; s1_txt_rx<=x-503; s1_txt_ry<=y-451; end
                end
                else if (x >= 509 && x < 514) begin
                    if (gun_d2 > 0 || gun_d1 > 0) begin s1_txt_hit<=1; s1_char_code<="0"+gun_d1; s1_txt_rx<=x-509; s1_txt_ry<=y-451; end
                end
                else if (x >= 515 && x < 520) begin
                    s1_txt_hit<=1; s1_char_code<="0"+gun_d0; s1_txt_rx<=x-515; s1_txt_ry<=y-451;
                end
            end
        end

        // --- NEW: PIPELINE ALIGNMENT FOR OTHER UI ELEMENTS ---
        // Registering these here ensures they have the same 1-clock latency as the text logic above.
        
        // Instruction
        if (instructionActive && instructionArea) begin r_instructionHit <= 1; r_instruction_addr <= w_instruction_addr; end 
        else r_instructionHit <= 0;
        
        // Sign
        if (signActive && signArea) begin r_signHit <= 1; r_sign_addr <= w_sign_addr; end 
        else r_signHit <= 0;

        // Heart
        if (heart_active) begin r_heartHit <= 1; r_heart_addr <= heart_addr; end
        else r_heartHit <= 0;

        // Gun Icon
        if (gunActive && gunArea) begin r_gunHit <= 1; r_gun_addr <= w_gun_final_addr; end
        else r_gunHit <= 0;

        // Bar
        if (barArea) begin r_barHit <= 1; r_bar_addr <= w_bar_final_addr; end
        else r_barHit <= 0;
    end
    
    wire [7:0] txt_calc_y = map_sprite_y[7:0] + s1_txt_ry[7:0];
    wire [7:0] txt_calc_x = map_sprite_x[7:0] + s1_txt_rx[7:0];
    wire [15:0] w_txt_final_addr = { txt_calc_y, txt_calc_x };

    // =========================================================
    // PIPELINE STAGE 2
    // =========================================================
    reg [15:0] addr_ui;
    reg hit_ui;
    
    reg [15:0] addr_game;
    reg hit_game;

    always @(*) begin
        // Group 1: UI Elements (Now using REGISTERED inputs for alignment)
        if (s1_txt_hit) begin hit_ui=1; addr_ui=w_txt_final_addr; end
        else if (r_instructionHit) begin hit_ui = 1; addr_ui=r_instruction_addr; end
        else if (r_signHit) begin hit_ui=1; addr_ui=r_sign_addr; end
        else if (r_heartHit) begin hit_ui=1; addr_ui=r_heart_addr; end
        else if (r_gunHit) begin hit_ui=1; addr_ui=r_gun_addr; end
        else if (r_barHit) begin hit_ui=1; addr_ui=r_bar_addr; end
        else begin hit_ui=0; addr_ui=0; end
        
        // Group 2: Game Elements
        if (fx_render) begin hit_game=1; addr_game=fx_addr; end
        else if (cloud_hit) begin hit_game=1; addr_game=w_cloud_addr; end
        else if (obj_render_flag) begin hit_game=1; addr_game=w_obj_addr; end
        else begin hit_game=0; addr_game=0; end
    end

    reg [15:0] s2_addr_A, s2_addr_B;
    always @(posedge Clk_In) begin
        // Port A (Character)
        if (charActive && charArea) s2_addr_A <= w_char_final_addr;
        else s2_addr_A <= 0;
        
        // Port B (Mixed)
        if (hit_ui) s2_addr_B <= addr_ui;
        else if (hit_game) s2_addr_B <= addr_game;
        else s2_addr_B <= 0;
    end

    // =========================================================
    // PIPELINE STAGE 3
    // =========================================================
    wire [11:0] color_A, color_B;
    memory u_rom_main (.Clk_In(Clk_In), .Read_Address_A(s2_addr_A), .Pixel_Color_A(color_A), .Read_Address_B(s2_addr_B), .Pixel_Color_B(color_B));
    
    wire is_A_Transparent = (color_A == 12'hC6B);
    wire is_B_Transparent = (color_B == 12'hC6B);
    
    // *** OPTIMIZATION: BITWISE LANE LOGIC ***
    // Replaces 12 comparators with 1 subtraction + 1 bitwise check
    wire [9:0] lane_dist = x - 160;
    // Check range (160 to 483) AND check mod 64 (using bottom 6 bits)
    wire lanes = (x >= 160 && x < 483) && (lane_dist[5:0] < 3);

    reg [11:0] final_pixel;
    always @(*) begin
        if (!is_A_Transparent) final_pixel = color_A;
        else if (!is_B_Transparent) final_pixel = color_B;
        else if (lanes) begin
            case (currentWeather)
                sunny : final_pixel = 12'hAAA;
                rainy : final_pixel = 12'h446;
                snowy : final_pixel = 12'h8cd;
                default : final_pixel = 12'hAAA;
            endcase
        end else final_pixel = 12'h002;
    end
    assign RED = final_pixel[11:8]; assign GREEN = final_pixel[7:4]; assign BLUE = final_pixel[3:0];

    // =========================================================
    // STATE MACHINE (UNCHANGED)
    // =========================================================
    always @(posedge Clk_In) begin
        if (!Reset) begin
            currentState <= startState;
            HP_Count <= 3'd6;
            score_d6<=0; score_d5<=0; score_d4<=0; score_d3<=0; score_d2<=0; score_d1<=0; score_d0<=0;
            gun_d2 <= 0; gun_d1 <= 0; gun_d0 <= 3;
            score_tick_counter <= 0; 
            show_hud <= 0; gun_count_active <= 0;
            freeze_timer <= 0;
            invincible_timer <= invincible_MAX; is_invincible <= 0;
            is_shooting_req <= 0;
            cloud1_pos_y <= $signed(cloud1_min_y);
        end else begin
            if (GameTick_Pulse) begin
                if (invincible_timer < invincible_MAX) begin
                    invincible_timer <= invincible_timer + 8'd1;
                    is_invincible <= 1;
                end else is_invincible <= 0;
            end
            
            case (currentState)
                startState: begin
                    score_d6<=0; score_d5<=0; score_d4<=0; score_d3<=0; score_d2<=0; score_d1<=0; score_d0<=0;
                    gun_d2 <= 0; gun_d1 <= 0; gun_d0 <= 3;
                    HP_Count <= 3'd6;
                    show_hud <= 1; gun_count_active <= 1;
                    freeze_timer <= 0; invincible_timer <= invincible_MAX; is_invincible <= 0;
                    is_shooting_req <= 0;
                    cloud1_pos_y <= $signed(cloud1_min_y);
                    if (Start_Pulse) currentState <= gameState;
                end
                gameState: begin
                    show_hud <= 1;
                    if (Shoot_Pulse && gun_count > 0 && !is_shooting_req) begin
                        is_shooting_req <= 1;
                        dec_gun_bcd();
                    end
                    if (bullet_fired_ack) is_shooting_req <= 0;
                    if (GameTick_Pulse) begin
                        if (score_tick_counter == 3) begin
                            inc_score_bcd();
                            score_tick_counter <= 0;
                        end else score_tick_counter <= score_tick_counter + 1;

                        if (bonus_score_from_obj > 0) inc_score_bcd();

                        if (currentWeather == rainy) begin
                            if (cloud1_pos_y < $signed(cloud1_max_y)) 
                                cloud1_pos_y <= cloud1_pos_y + 1;
                        end 
                        else begin
                            if (cloud1_pos_y > $signed(cloud1_min_y)) 
                                cloud1_pos_y <= cloud1_pos_y - 1;
                        end

                        if (collisionType != 0) begin 
                            if (collisionType == 3'b001) begin
                                inc_gun_bcd();
                            end else if (collisionType == 3'b100) begin
                                if (HP_Count < 5) HP_Count <= HP_Count + 2;
                                else if (HP_Count < 6) HP_Count <= HP_Count + 1;
                            end else if (collisionType == 3'b101) begin
                                if (HP_Count < 6) HP_Count <= HP_Count + 1;
                            end else if (!is_invincible) begin
                                if (collisionType == 3'b010) begin 
                                    case (currentWeather)
                                        snowy : begin
                                            if (HP_Count >= 2) HP_Count <= HP_Count - 2;
                                            else HP_Count <= 0;
                                        end default: HP_Count <= HP_Count - 1;
                                    endcase
                                end else if (collisionType == 3'b011) HP_Count <= HP_Count - 1;
                                freeze_timer <= 7'd0;
                                invincible_timer <= 8'd0;
                                currentState <= freezeState;
                            end 
                        end
                    end
                    if (Start_Pulse) currentState <= pauseState;
                    if (HP_Count <= 0) begin 
                        currentState <= endState;
                    end
                end
                pauseState: begin
                    if (Start_Pulse) currentState <= gameState;
                    else if (Shoot_Pulse) currentState <= endState;
                end
                freezeState: begin
                    if (GameTick_Pulse) begin
                        if (freeze_timer < freeze_MAX) freeze_timer <= freeze_timer + 7'd1;
                        else begin
                            freeze_timer <= 7'd0;
                            currentState <= gameState;
                        end
                    end
                end
                endState: begin
                    show_hud <= 1;
                    gun_count_active <= 1; HP_Count <= 3'd0;
                    if (Start_Pulse) currentState <= startState;
                end
                default: currentState <= startState;
            endcase
        end
    end

endmodule