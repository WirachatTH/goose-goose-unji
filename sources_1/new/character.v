`timescale 1ns / 1ps

module character(
    input Reset,
    input GameTick,
    input Left,
    input Right,
    input [2:0] currentState,
    input [9:0] gun_count,
    input is_invincible,
    output reg [2:0] char_frame,
    output [9:0] x_out,
    output [9:0] y_out,
    output is_visible //สถานะอมตะ
    );
    
    //Config
    parameter startState = 3'b000;
    parameter gameState  = 3'b001;
    parameter pauseState = 3'b010;
    parameter freezeState = 3'b011;
    parameter endState = 3'b100;

    parameter CENTER_X = 320; 
    parameter LANE_WIDTH = 64;
    
    //Character Sizes
    parameter char_w_type1 = 25; parameter char_h_type1 = 40;
    parameter char_w_type2 = 17; parameter char_h_type2 = 40;

    //Variables
    reg [2:0] lane;
    reg [9:0] char_w, char_h;
    reg [9:0] pos_x, pos_y;
    
    //ตัวละครมีสองสถานะ(มีปืนและไม่มีปืน) ที่มีขนาดแตกต่างกัน ดังนั้นต้องอัพเดทตามเฟรมปัจจุบัน
    always @(*) begin
        case (char_frame)
            3'd0, 3'd1, 3'd2: begin char_w = char_w_type1; char_h = char_h_type1; end
            3'd3, 3'd4:       begin char_w = char_w_type2; char_h = char_h_type2; end
            default:          begin char_w = char_w_type1; char_h = char_h_type1; end
        endcase
    end

    //Input Logic
    reg Left_Prev, Right_Prev;
    wire Left_Pulse  = Left && !Left_Prev;
    wire Right_Pulse = Right && !Right_Prev;

    //Movement Parameters
    parameter MOVE_STEPS = 4; 
    parameter MOVE_SIZE = LANE_WIDTH / MOVE_STEPS; 

    reg is_moving;      
    reg moving_dir;
    reg [9:0] target_x;        
    reg [2:0] move_count; 
    
    //Animation Counter
    parameter COUNT_MAX = 12;
    reg [3:0] frame_counter;
    
    //Invincibility Timer
    reg [2:0] blink_timer; 

    /*----------อัพเดทสถานะการเป็นอมตะ----------*/
    assign is_visible = ((!is_invincible) || blink_timer[2]) && currentState != endState;

    /*----------คำนวณตำแหน่ง----------*/
    wire signed [11:0] lane_offset = ($signed({1'b0, lane}) - 4'sd3) * $signed(LANE_WIDTH);
    wire signed [11:0] ideal_center = $signed(CENTER_X) + lane_offset;
    wire signed [11:0] ideal_pos_x  = ideal_center - $signed({1'b0, char_w}) / 2;

    /*----------ANIMATION----------*/
    always @(posedge GameTick) begin
        if (!Reset || currentState == startState || currentState == endState) begin
            //Reset Animation
            if (gun_count > 10'd0) char_frame <= 3'd3;
            else char_frame <= 3'd0;
            frame_counter <= 4'd0;
            blink_timer <= 0;
            
        end else if (currentState == pauseState) begin
            //Freeze Animation
            frame_counter <= frame_counter;
            blink_timer <= blink_timer;
            
        end else begin
            //--- BLINK TIMER ---
            blink_timer <= blink_timer + 1;

            if (is_invincible) begin
                //ถ้าเป็นอมตะ จะไม่เปลี่ยน frame
                if (gun_count > 0) char_frame <= 3'd3;
                else char_frame <= 3'd0;
            end 
            else begin
                //Walking Animation
                if (frame_counter < COUNT_MAX) begin
                    frame_counter <= frame_counter + 4'd1;
                end else begin
                    frame_counter <= 4'd0;
                    case (char_frame)
                        3'd0: begin if (gun_count > 0) char_frame<=3'd3; else char_frame<=3'd1; end
                        3'd1: begin if (gun_count > 0) char_frame<=3'd3; else char_frame<=3'd2; end
                        3'd2: begin if (gun_count > 0) char_frame<=3'd3; else char_frame<=3'd0; end
                        3'd3: begin if (gun_count > 0) char_frame<=3'd4; else char_frame<=3'd0; end
                        3'd4: begin if (gun_count > 0) char_frame<=3'd3; else char_frame<=3'd0; end
                    endcase
                end
            end
        end
    end

    /*----------MOVEMENT----------*/
    always @(posedge GameTick or negedge Reset) begin
        if (!Reset) begin
            lane <= 3'd3;
            is_moving <= 0;
            move_count <= 0;
            moving_dir <= 0;
            Left_Prev <= 0;
            Right_Prev <= 0;
            //Initial Position
            pos_x <= CENTER_X - (char_w_type1 / 2);
            pos_y <= 420 - (char_h_type1 / 2);
            
        end else begin
            if (currentState == startState) begin
                lane <= 3'd3;
                is_moving <= 0; 
                move_count <= 0;
                moving_dir <= 0;
                Left_Prev <= 0;
                Right_Prev <= 0;
                
                if (gun_count > 0) pos_y <= 420 - (char_h_type2 / 2);
                else pos_y <= 420 - (char_h_type1 / 2);
                
                //Force Sync
                pos_x <= ideal_pos_x[9:0];
            end 
            else if (currentState == gameState) begin
                
                Left_Prev <= Left;
                Right_Prev <= Right;

                //1. Idle Logic
                if (is_moving == 1'b0) begin 
                    pos_x <= ideal_pos_x[9:0];

                    //Input Check
                    if (Left_Pulse && (lane > 3'd1)) begin 
                        is_moving <= 1'b1;
                        moving_dir <= 1'b0; 
                        lane <= lane - 3'd1; 
                        target_x <= pos_x - LANE_WIDTH;
                        move_count <= 3'd0;
                    end 
                    else if (Right_Pulse && (lane < 3'd5)) begin 
                        is_moving <= 1'b1;
                        moving_dir <= 1'b1; 
                        lane <= lane + 3'd1; 
                        target_x <= pos_x + LANE_WIDTH;
                        move_count <= 3'd0;
                    end
                end

                //2. การเคลื่อนที่ตามปุ่มที่กด
                if (is_moving == 1'b1) begin
                    if (move_count < MOVE_STEPS) begin 
                        if (moving_dir == 1'b1) pos_x <= pos_x + MOVE_SIZE;
                        else pos_x <= pos_x - MOVE_SIZE;
                        move_count <= move_count + 3'd1;
                    end 
                    else begin 
                        is_moving <= 1'b0;
                    end
                end
                
            end 
        end
    end
    
    assign x_out = pos_x;
    assign y_out = pos_y; 
endmodule