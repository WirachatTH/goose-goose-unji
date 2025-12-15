`timescale 1ns / 1ps

module TopModule(
    input Clk_In,
    input Reset,
    input Left_Btn,
    input Right_Btn,
    input Shoot_Btn,
    input SwitchItem_Btn,
    input StartStop_Btn,
    
    // Outputs to VGA Port
    output HS,
    output VS,
    output [3:0] RED,
    output [3:0] GREEN,
    output [3:0] BLUE
    );
    
    // -----------------------------------------------------------
    // 1. INPUT DEBOUNCING
    // -----------------------------------------------------------
    wire Left;
    wire Right;
    wire Shoot;
    wire SwitchItem;
    wire StartStop;
    
    InputDebounce u_db_left (
        .Reset(Reset),
        .Clk_In(Clk_In),
        .Btn_In(Left_Btn),
        .Btn_Out(Left)
    );
    
    InputDebounce u_db_right (
        .Reset(Reset),
        .Clk_In(Clk_In),
        .Btn_In(Right_Btn),
        .Btn_Out(Right)
    );
    
    InputDebounce u_db_shoot (
        .Reset(Reset),
        .Clk_In(Clk_In),
        .Btn_In(Shoot_Btn),
        .Btn_Out(Shoot)
    );
    
    InputDebounce u_db_switch (
        .Reset(Reset),
        .Clk_In(Clk_In),
        .Btn_In(SwitchItem_Btn),
        .Btn_Out(SwitchItem)
    );
    
    InputDebounce u_db_startstop (
        .Reset(Reset),
        .Clk_In(Clk_In),
        .Btn_In(StartStop_Btn),
        .Btn_Out(StartStop)
    );
    
    // -----------------------------------------------------------
    // 2. CLOCK GENERATION
    // -----------------------------------------------------------
    wire GameTick;
    
    Clk_div u_gametick (
        .Clk_In(Clk_In),
        .Reset(Reset),
        .Clk_Out(GameTick)
    );
    
    // -----------------------------------------------------------
    // 3. VGA CONTROLLER & PIPELINE SYNCHRONIZATION
    // -----------------------------------------------------------
    wire [9:0] x;
    wire [9:0] y;
    
    // สัญญาณ "สด" ที่ออกจาก VGA Controller (ยังไม่ Delay)
    wire HS_raw; 
    wire VS_raw;
    
    vga u_vga (
        .Clk_In(Clk_In),
        .Reset(Reset),
        .HS(HS_raw),
        .VS(VS_raw),
        .x(x),
        .y(y)
    );

    reg [4:0] hs_delay;
    reg [4:0] vs_delay;
    
    always @(posedge Clk_In) begin
    //Allowing more time for the game engine to calculate
        hs_delay <= {hs_delay[3:0], HS_raw};
        vs_delay <= {vs_delay[3:0], VS_raw};
    end
    
    assign HS = hs_delay[4];
    assign VS = vs_delay[4];

    // -----------------------------------------------------------
    // 4. GAME ENGINE
    // -----------------------------------------------------------
    Engine u_engine (
        .Clk_In(Clk_In),
        .Reset(Reset),
        .GameTick(GameTick),
        .Left(Left),
        .Right(Right),
        .Shoot(Shoot),
        .SwitchItem(SwitchItem),
        .StartStop(StartStop),
        .x(x), // ส่ง x, y "สด" เข้าไปเริ่มคำนวณใน Pipeline
        .y(y),
        .RED(RED),
        .GREEN(GREEN),
        .BLUE(BLUE)
    );
    
endmodule