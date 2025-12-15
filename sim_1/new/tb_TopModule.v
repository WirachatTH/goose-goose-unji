//`timescale 1ns / 1ps

//module tb_TopModule;

//    // --- Inputs ---
//    reg Clk_In;
//    reg Reset;
//    reg Left_Btn;
//    reg Right_Btn;
//    reg Shoot_Btn;
//    reg SwitchItem_Btn;
//    reg StartStop_Btn;

//    // --- Outputs ---
//    wire HS;
//    wire VS;
//    wire [3:0] RED;
//    wire [3:0] GREEN;
//    wire [3:0] BLUE;

//    // --- Instantiate the Top Module (DUT) ---
//    TopModule uut (
//        .Clk_In(Clk_In), 
//        .Reset(Reset), 
//        .Left_Btn(Left_Btn), 
//        .Right_Btn(Right_Btn), 
//        .Shoot_Btn(Shoot_Btn), 
//        .SwitchItem_Btn(SwitchItem_Btn), 
//        .StartStop_Btn(StartStop_Btn), 
//        .HS(HS), 
//        .VS(VS), 
//        .RED(RED), 
//        .GREEN(GREEN), 
//        .BLUE(BLUE)
//    );

//    // --- Clock Generation (100MHz) ---
//    always #5 Clk_In = ~Clk_In; // Toggle every 5ns = 10ns period = 100MHz

//    // --- Simulation Script ---
//    initial begin
//        // 1. Initialize Inputs
//        $dumpvars(0);
//        $dumpfile("waveform.vcd");
//        Clk_In = 0;
//        Reset = 0; // Active Low (กด Reset ค้างไว้ก่อน)
//        Left_Btn = 0;
//        Right_Btn = 0;
//        Shoot_Btn = 0;
//        SwitchItem_Btn = 0;
//        StartStop_Btn = 0;

//        // 2. Apply Reset
//        $display("Applying Reset...");
//        #100;
//        Reset = 1; // ปล่อย Reset (ระบบเริ่มทำงาน)
//        #100;
        
//        $display("System Ready. Waiting for Start...");
//        #1000; // รอสักพัก

//        // 3. Action: Press Start Button
//        // หมายเหตุ: ปกติต้องรอนานมากเพื่อให้ Debounce ทำงาน
//        // แต่เราใช้ defparam ด้านล่างเพื่อเร่งความเร็วแล้ว กดแค่ 2000ns ก็พอ
//        $display("Action: Pressing START...");
//        StartStop_Btn = 1;
//        #2000; 
//        StartStop_Btn = 0;
        
//        // รอให้ State เปลี่ยน (สังเกต currentState ใน Waveform)
//        #5000; 

//        // 4. Action: Move Right
//        $display("Action: Moving RIGHT...");
//        Right_Btn = 1;
//        #50000; // กดค้างไว้นานหน่อยให้ตัวละครเดิน
//        Right_Btn = 0;
        
//        // 5. Action: Shoot
//        $display("Action: SHOOTING...");
//        Shoot_Btn = 1;
//        #2000; // กดแล้วปล่อย
//        Shoot_Btn = 0;

//        // Run simulation for a bit longer to see bullet travel
//        #100000;
        
//        $display("Simulation Finished.");
//        $finish;
//    end

//    // --- SPEED UP SIMULATION ---
//    // override parameter ของ InputDebounce ให้เหลือน้อยๆ จะได้ไม่ต้องรอปุ่มนาน
//    // (Vivado รองรับการทำแบบนี้ใน Simulation)
//    defparam uut.u_db_left.COUNT_MAX = 100;
//    defparam uut.u_db_right.COUNT_MAX = 100;
//    defparam uut.u_db_shoot.COUNT_MAX = 100;
//    defparam uut.u_db_switch.COUNT_MAX = 100;
//    defparam uut.u_db_startstop.COUNT_MAX = 100;

//endmodule
`timescale 1ns / 1ps

module tb_TopModule;

    // Inputs
    reg Clk_In;
    reg Reset;
    reg Left_Btn;
    reg Right_Btn;
    reg Shoot_Btn;
    reg SwitchItem_Btn;
    reg StartStop_Btn;

    // Outputs
    wire HS;
    wire VS;
    wire [3:0] RED;
    wire [3:0] GREEN;
    wire [3:0] BLUE;

    // Instantiate (DUT)
    TopModule uut (
        .Clk_In(Clk_In), 
        .Reset(Reset), 
        .Left_Btn(Left_Btn), 
        .Right_Btn(Right_Btn), 
        .Shoot_Btn(Shoot_Btn), 
        .SwitchItem_Btn(SwitchItem_Btn), 
        .StartStop_Btn(StartStop_Btn), 
        .HS(HS), 
        .VS(VS), 
        .RED(RED), 
        .GREEN(GREEN), 
        .BLUE(BLUE)
    );

    always #5 Clk_In = ~Clk_In; // 100MHz

    initial begin
        // 1. Init
        Clk_In = 0; Reset = 0;
        Left_Btn = 0; Right_Btn = 0; Shoot_Btn = 0; SwitchItem_Btn = 0; StartStop_Btn = 0;
        
        // 2. Reset
        #100; Reset = 1; #100;
        
        // 3. START GAME
        $display("Action: Pressing START");
        StartStop_Btn = 1;
        #2000; 
        StartStop_Btn = 0;
        
        // 4. MOVE & SHOOT (จำลองการเล่น)
        #10000; 
        $display("Action: Moving & Shooting");
        Right_Btn = 1;
        Shoot_Btn = 1;
        #5000;
        Shoot_Btn = 0;
        #20000;
        Right_Btn = 0;

        // 5. RUN LONGER (รันยาวๆ ให้เห็นการเปลี่ยนแปลง)
        // รันยาว 17ms (17,000,000 ns) เพื่อให้เห็นภาพครบ 1 เฟรม
        $display("Status: Running Simulation for 1 full frame...");
        #17000000; 
        
        $display("Simulation Finished");
        $finish;
    end
    
    // --- CHEAT CODES (เร่งความเร็ว Simulation) ---
    // เร่งปุ่มกด
    defparam uut.u_db_left.COUNT_MAX = 10;
    defparam uut.u_db_right.COUNT_MAX = 10;
    defparam uut.u_db_shoot.COUNT_MAX = 10;
    defparam uut.u_db_switch.COUNT_MAX = 10;
    defparam uut.u_db_startstop.COUNT_MAX = 10;
    
    // *** เร่งความเร็วเกม (สำคัญมาก) ***
    // เปลี่ยนเลข 100 เป็นค่าน้อยๆ เพื่อให้ GameTick รัวยิกๆ ใน Sim
    // (ต้องแน่ใจว่าแก้ Clk_div.v ให้มี parameter ชื่อ MAX_COUNT แล้วนะครับ)
    defparam uut.u_gametick.COUNT_MAX = 100; 

endmodule