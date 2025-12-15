`timescale 1ns / 1ps

module ExplosionFxManager(
    input Clk_In,
    input Reset,
    input GameTick,
    input [2:0] currentState,
    
    // --- Trigger Interface ---
    input [3:0] world_speed,
    input trigger_req,
    input [1:0] anim_type,
    input is_moving_down,
    input [9:0] start_x,
    input [9:0] start_y,

    // --- Rendering Interface ---
    input [9:0] vga_x,
    input [9:0] vga_y,
    output reg render_enable,
    output reg [15:0] rom_addr
    );

    // =================================================================
    // 1. CONFIG & POOL (OPTIMIZED)
    // =================================================================
    // *** OPTIMIZATION: Reduced from 10 to 6 to save timing ***
    parameter MAX_EXPLOSIONS = 6; 
    parameter TICKS_PER_FRAME = 20;
    parameter SPRITE_SHEET_W = 256;
    
    // States
    parameter startState = 3'b000;
    parameter gameState = 3'b001;
    parameter pauseState = 3'b010;
    parameter freezeState = 3'b011;
    parameter endState = 3'b100;

    reg active [0:MAX_EXPLOSIONS-1];
    reg [1:0] type_store [0:MAX_EXPLOSIONS-1];
    reg move_flag [0:MAX_EXPLOSIONS-1];
    
    reg [9:0] pos_x [0:MAX_EXPLOSIONS-1];
    reg signed [11:0] pos_y [0:MAX_EXPLOSIONS-1];
    
    reg [1:0] frame_idx [0:MAX_EXPLOSIONS-1];
    reg [4:0] tick_counter [0:MAX_EXPLOSIONS-1];

    // *** NEW: Pre-calculated Cache (Relieves Timing Pressure) ***
    reg [9:0] cache_w [0:MAX_EXPLOSIONS-1];
    reg [9:0] cache_h [0:MAX_EXPLOSIONS-1];
    reg [9:0] cache_ox [0:MAX_EXPLOSIONS-1];
    reg [9:0] cache_oy [0:MAX_EXPLOSIONS-1];

    integer i;

    // =================================================================
    // 2. UPDATE LOGIC (GameTick) - PRE-CALCULATIONS HAPPEN HERE
    // =================================================================
    always @(posedge GameTick or negedge Reset) begin
        if (!Reset) begin
            for(i=0; i<MAX_EXPLOSIONS; i=i+1) active[i] <= 0;
        end else begin
            if (currentState == startState || currentState == endState) begin
                for(i=0; i<MAX_EXPLOSIONS; i=i+1) active[i] <= 0;
            end 
            else if (currentState == gameState || currentState == freezeState) begin
                
                // --- Spawn New Explosion ---
                if (trigger_req) begin
                    begin : find_slot
                        reg already_exists;
                        already_exists = 0;
                        for(i=0; i<MAX_EXPLOSIONS; i=i+1) begin
                            if (active[i] && pos_x[i] == start_x && pos_y[i] == $signed({2'b00, start_y})) 
                                already_exists = 1;
                        end

                        if (!already_exists) begin
                            for(i=0; i<MAX_EXPLOSIONS; i=i+1) begin
                                if (!active[i]) begin
                                    active[i] <= 1;
                                    type_store[i] <= anim_type;
                                    move_flag[i] <= is_moving_down;
                                    pos_x[i] <= start_x;
                                    pos_y[i] <= $signed({2'b00, start_y}); 
                                    frame_idx[i] <= 0;
                                    tick_counter[i] <= 0;
                                    disable find_slot;
                                end
                            end
                        end
                    end
                end
                
                // --- Update Active Explosions & CACHE VALUES ---
                for(i=0; i<MAX_EXPLOSIONS; i=i+1) begin
                    if (active[i]) begin
                        // 1. Movement
                        if (move_flag[i] && currentState == gameState) pos_y[i] <= pos_y[i] + world_speed;

                        // 2. Animation
                        if (tick_counter[i] < TICKS_PER_FRAME-1) begin
                            tick_counter[i] <= tick_counter[i] + 1;
                        end else begin
                            tick_counter[i] <= 0;
                            if ( (type_store[i] <= 1 && frame_idx[i] < 2) || 
                                 (type_store[i] >= 2 && frame_idx[i] < 1) ) 
                            begin
                                frame_idx[i] <= frame_idx[i] + 1;
                            end else begin
                                active[i] <= 0;
                            end
                        end

                        // 3. *** CRITICAL OPTIMIZATION: UPDATE CACHE HERE ***
                        // This moves the massive "Case" logic to the slow clock
                        case(type_store[i])
                            2'd0: begin // Poo Normal
                                case(frame_idx[i])
                                    0: begin cache_w[i]<=27; cache_h[i]<=20; cache_ox[i]<=140; cache_oy[i]<=0; end
                                    1: begin cache_w[i]<=33; cache_h[i]<=18; cache_ox[i]<=167; cache_oy[i]<=0; end
                                    2: begin cache_w[i]<=29; cache_h[i]<=12; cache_ox[i]<=200; cache_oy[i]<=0; end
                                endcase
                            end
                            2'd1: begin // Poo Snowy
                                case(frame_idx[i])
                                    0: begin cache_w[i]<=27; cache_h[i]<=20; cache_ox[i]<=140; cache_oy[i]<=20; end
                                    1: begin cache_w[i]<=33; cache_h[i]<=18; cache_ox[i]<=167; cache_oy[i]<=20; end
                                    2: begin cache_w[i]<=29; cache_h[i]<=12; cache_ox[i]<=200; cache_oy[i]<=20; end
                                endcase
                            end
                            2'd2: begin // Goose Normal
                                case(frame_idx[i])
                                    0: begin cache_w[i]<=26; cache_h[i]<=25; cache_ox[i]<=205; cache_oy[i]<=72; end
                                    1: begin cache_w[i]<=25; cache_h[i]<=17; cache_ox[i]<=231; cache_oy[i]<=74; end
                                    default: begin cache_w[i]<=26; cache_h[i]<=25; cache_ox[i]<=205; cache_oy[i]<=72; end
                                endcase
                            end
                            2'd3: begin // Goose Snowy
                                case(frame_idx[i])
                                    0: begin cache_w[i]<=26; cache_h[i]<=25; cache_ox[i]<=205; cache_oy[i]<=122; end
                                    1: begin cache_w[i]<=25; cache_h[i]<=17; cache_ox[i]<=231; cache_oy[i]<=124; end
                                    default: begin cache_w[i]<=26; cache_h[i]<=25; cache_ox[i]<=205; cache_oy[i]<=122; end
                                endcase
                            end
                        endcase
                    end
                end
            end
        end
    end

    // =================================================================
    // 3. RENDER PIPELINE (OPTIMIZED)
    // =================================================================
    
    // --- STAGE 1: Y-Hit Test & Fetch Cached Values ---
    reg [MAX_EXPLOSIONS-1:0] s1_hits;
    reg [9:0] s1_x;
    reg signed [11:0] s1_diff_y [0:MAX_EXPLOSIONS-1];
    
    reg [9:0] s1_w [0:MAX_EXPLOSIONS-1];
    reg [9:0] s1_h [0:MAX_EXPLOSIONS-1];
    reg [9:0] s1_ox [0:MAX_EXPLOSIONS-1];
    reg [9:0] s1_oy [0:MAX_EXPLOSIONS-1];
    
    integer k;
    
    always @(posedge Clk_In) begin
        s1_x <= vga_x;
        for(k=0; k<MAX_EXPLOSIONS; k=k+1) begin
            s1_hits[k] <= 0;
            
            // *** OPTIMIZATION: No Case Statement Here! Just read the Cache ***
            if (active[k]) begin
                // Check Y bounds using CACHED height
                if ($signed({2'b00, vga_y}) >= pos_y[k] && $signed({2'b00, vga_y}) < pos_y[k] + cache_h[k]) begin
                    s1_hits[k] <= 1;
                    s1_diff_y[k] <= $signed({2'b00, vga_y}) - pos_y[k];
                    // Pass Cached values to next stage
                    s1_w[k] <= cache_w[k]; 
                    s1_h[k] <= cache_h[k]; 
                    s1_ox[k] <= cache_ox[k]; 
                    s1_oy[k] <= cache_oy[k];
                end
            end
        end
    end

    // --- STAGE 2: X-Hit Test & Addr Calc ---
    reg s2_hit;
    reg [15:0] s2_addr;
    reg signed [11:0] s2_diff_x;
    
    always @(posedge Clk_In) begin
        s2_hit = 0;
        s2_addr = 0;
        
        // Priority encoder
        for(k=0; k<MAX_EXPLOSIONS; k=k+1) begin
            if (s1_hits[k]) begin
                s2_diff_x = $signed({2'b00, s1_x}) - $signed({2'b00, pos_x[k]});
                
                if (s2_diff_x >= 0 && s2_diff_x < s1_w[k]) begin
                    s2_hit = 1;
                    s2_addr = { (s1_oy[k][7:0] + s1_diff_y[k][7:0]), (s1_ox[k][7:0] + s2_diff_x[7:0]) };
                end
            end
        end
    end

    // --- STAGE 3: Output ---
    always @(posedge Clk_In) begin
        render_enable <= s2_hit;
        rom_addr <= s2_addr;
    end

endmodule