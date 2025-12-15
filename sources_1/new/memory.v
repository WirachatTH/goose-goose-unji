`timescale 1ns / 1ps

module memory(
    input Clk_In,
    // Port A (สำหรับ Character)
    input [15:0] Read_Address_A,
    output reg [11:0] Pixel_Color_A,
    
    // Port B (สำหรับ Object / Bar)
    input [15:0] Read_Address_B,
    output reg [11:0] Pixel_Color_B
    );

    parameter MEM_DEPTH = 65_536;
    reg [11:0] mem [0:MEM_DEPTH - 1];

    initial begin
        $readmemh("sprite.mem", mem);
    end
    
    always @(posedge Clk_In) begin
        Pixel_Color_A <= mem[Read_Address_A]; // อ่านช่องทางที่ 1
        Pixel_Color_B <= mem[Read_Address_B]; // อ่านช่องทางที่ 2 พร้อมกัน
    end
endmodule