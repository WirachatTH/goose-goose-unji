`timescale 1ns / 1ps

module memory(
    input Clk_In,
    //Port A (สำหรับ Character)
    input [15:0] Read_Address_A,
    output reg [11:0] Pixel_Color_A,
    
    //Port B (สำหรับ Object, UI)
    input [15:0] Read_Address_B,
    output reg [11:0] Pixel_Color_B
    );

    parameter MEM_DEPTH = 65_536; //Array ที่ใหญ่ขนาดนี้จะบังคับให้ใช้ Dual-Port BRAM
    reg [11:0] mem [0:MEM_DEPTH - 1];

    initial begin
        $readmemh("sprite.mem", mem);
    end
    
    always @(posedge Clk_In) begin
        Pixel_Color_A <= mem[Read_Address_A]; //อ่าน portA, portB พร้อมกัน
        Pixel_Color_B <= mem[Read_Address_B];
    end
endmodule